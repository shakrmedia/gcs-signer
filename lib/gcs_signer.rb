# frozen_string_literal: true

require "json"
require "base64"
require "openssl"
require "addressable"

# Creates signed_url for a file on Google Cloud Storage.
#
#  signer = GcsSigner.new(path: "/Users/leo/private/service_account.json")
#  signer.sign "your-bucket", "object/name"
#  # => "https://storage.googleapis.com/your-bucket/object/name?..."
class GcsSigner
  ENV_KEYFILE_PATH = ENV["GOOGLE_CLOUD_KEYFILE"] || ENV["GOOGLE_APPLICATION_CREDENTIALS"]
  ENV_KEYFILE_JSON = ENV["GOOGLE_CLOUD_KEYFILE_JSON"]
  DEFAULT_GCS_URL = Addressable::URI.new(
    scheme: "https", host: "storage.googleapis.com"
  ).freeze

  # gcs-signer requires credential that can access to GCS.
  # [path] the path of the service_account json file.
  # [keyfile_string] ...or the content of the service_account json file.
  # [gcs_url] Custom GCS url when signing a url.
  #
  # or if you also use \+google-cloud+ gem. you can authenticate
  # using environment variable that uses.
  def initialize(path: nil, keyfile_json: nil, gcs_url: DEFAULT_GCS_URL)
    keyfile_json ||= path.nil? ? look_for_environment_variables : File.read(path)
    fail AuthError, "No credentials given." if keyfile_json.nil?

    @credentials = JSON.parse(keyfile_json)
    @key = OpenSSL::PKey::RSA.new(@credentials["private_key"])
    @gcs_url = Addressable::URI.parse(gcs_url)
  end

  # @return [String] Signed url
  # Generates signed url.
  # [bucket] the name of the Cloud Storage bucket that contains the object.
  # [key] the name of the object for signed url.
  # Variable options are available:
  # [version] signature version; \+:v2+ or \+:v4+
  # [expires] Time(stamp in UTC) when the signed url expires.
  # [valid_for] ...or how much seconds is the signed url available.
  # [response_content_disposition] Content-Disposition of the signed URL.
  # [response_content_type] Content-Type of the signed URL.
  #
  # If you set neither \+expires+ nor \+valid_for+,
  # it will set to 300 seconds by default.
  #
  #  # default is 5 minutes
  #  signer.sign_url("bucket-name", "path/to/file")
  #
  #  # You can give Time object.
  #  signer.sign_url("bucket-name", "path/to/file",
  #                   expires: Time.new(2016, 12, 26, 14, 31, 48, "+09:00"))
  #
  #  # You can give how much seconds is the signed url valid.
  #  signer.sign_url("bucket", "path/to/file", valid_for: 30 * 60)
  #
  #  # If you use ActiveSupport, you can also do some magic.
  #  signer.sign_url("bucket", "path/to/file", valid_for: 40.minutes)
  #
  def sign_url(bucket, key, version: :v2, **options)
    case version
    when :v2
      sign_url_v2(bucket, key, **options)
    when :v4
      sign_url_v4(bucket, key, **options)
    else
      fail ArgumentError, "Version not supported: #{version.inspect}"
    end
  end

  def sign_url_v2(bucket, key, method: "GET", valid_for: 300, **options)
    url = @gcs_url + "./#{request_path(bucket, key)}"
    expires_at = options[:expires] || Time.now.utc.to_i + valid_for.to_i
    sign_payload = [method, "", "", expires_at.to_i, url.path].join("\n")

    url.query_values = (options[:params] || {}).merge(
      "GoogleAccessId" => @credentials["client_email"],
      "Expires" => expires_at.to_i,
      "Signature" => sign_v2(sign_payload),
      "response-content-disposition" => options[:response_content_disposition],
      "response-content-type" => options[:response_content_type]
    ).compact

    url.to_s
  end

  def sign_url_v4(bucket, key, method: "GET", headers: {}, **options)
    url = @gcs_url + "./#{request_path(bucket, key)}"
    time = Time.now.utc

    request_headers = headers.merge(host: @gcs_url.host).transform_keys(&:downcase)
    signed_headers = request_headers.keys.sort.join(";")
    scopes = [time.strftime("%Y%m%d"), "auto", "storage", "goog4_request"].join("/")

    url.query_values = build_query_params(time, scopes, signed_headers, **options)

    canonical_request = [
      method, url.path.to_s, url.query,
      *request_headers.sort.map { |header| header.join(":") },
      "", signed_headers, "UNSIGNED-PAYLOAD"
    ].join("\n")

    sign_payload = [
      "GOOG4-RSA-SHA256", time.strftime("%Y%m%dT%H%M%SZ"), scopes,
      Digest::SHA256.hexdigest(canonical_request)
    ].join("\n")

    url.query += "&X-Goog-Signature=#{sign_v4(sign_payload)}"
    url.to_s
  end

  # @return [String] contains \+project_id+ and \+client_email+
  # Prevents confidential information (like private key) from exposing
  # when used with interactive shell such as \+pry+ and \+irb+.
  def inspect
    "#<GcsSigner " \
    "project_id: #{@credentials['project_id']} " \
    "client_email: #{@credentials['client_email']}>"
  end

  private

  def look_for_environment_variables
    ENV_KEYFILE_PATH.nil? ? ENV_KEYFILE_JSON : File.read(ENV_KEYFILE_PATH)
  end

  def request_path(bucket, object)
    [
      bucket,
      Addressable::URI.encode_component(
        object, Addressable::URI::CharacterClasses::UNRESERVED
      )
    ].join("/")
  end

  def sign_v2(string)
    Base64.strict_encode64(sign(string))
  end

  def sign_v4(string)
    sign(string).unpack1("H*")
  end

  # Signs the string with the given private key.
  def sign(string)
    @key.sign(OpenSSL::Digest.new("SHA256"), string)
  end

  # only used in v4
  def build_query_params(time, scopes, signed_headers, valid_for: 300, **options)
    goog_expires = if options[:expires]
                     options[:expires].to_i - time.to_i
                   else
                     valid_for.to_i
                   end.clamp(0, 604_800)

    (options[:params] || {}).merge(
      "X-Goog-Algorithm" => "GOOG4-RSA-SHA256",
      "X-Goog-Credential" => [@credentials["client_email"], scopes].join("/"),
      "X-Goog-Date" => time.strftime("%Y%m%dT%H%M%SZ"),
      "X-Goog-Expires" => goog_expires,
      "X-Goog-SignedHeaders" => signed_headers,
      "response-content-disposition" => options[:response_content_disposition],
      "response-content-type" => options[:response_content_type]
    ).compact.sort
  end

  # raised When GcsSigner could not find service_account JSON file.
  class AuthError < StandardError; end
end
