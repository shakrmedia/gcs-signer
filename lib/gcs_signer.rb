# frozen_string_literal: true

require "base64"
require "erb"
require "json"
require "openssl"
require "uri"

# Creates signed_url for a file on Google Cloud Storage.
#
#  signer = GcsSigner.new(path: "/Users/leo/private/service_account.json")
#  signer.sign "your-bucket", "object/name"
#  # => "https://storage.googleapis.com/your-bucket/object/name?..."
class GcsSigner
  VERSION = "0.3.0"

  # gcs-signer requires credential that can access to GCS.
  # [path] the path of the service_account json file.
  # [json_string] ...or the content of the service_account json file.
  # [gcs_url] Custom GCS url when signing a url.
  #
  # or if you also use \+google-cloud+ gem. you can authenticate
  # using environment variable that uses.
  def initialize(path: nil, json_string: nil, gcs_url: nil)
    json_string ||= File.read(path) unless path.nil?
    json_string = look_for_environment_variables if json_string.nil?

    fail AuthError, "No credentials given." if json_string.nil?
    @credentials = JSON.parse(json_string)
    @key = OpenSSL::PKey::RSA.new(@credentials["private_key"])

    @gcs_url = gcs_url || "https://storage.googleapis.com"
  end

  # @return [String] Signed url
  # Generates signed url.
  # [bucket] the name of the Cloud Storage bucket that contains the object.
  # [object_name] the name of the object for signed url..
  # Variable options are available:
  # [expires] Time(stamp in UTC) when the signed url expires.
  # [valid_for] ...or how much seconds is the signed url available.
  # [google_access_id] Just in case if you want to change \+GoogleAccessId+
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
  # For details information of another options,
  # like \+method+, \+md5+, and \+content_type+. See:
  # https://cloud.google.com/storage/docs/access-control/signed-urls
  #
  def sign_url(bucket, object_name, options = {})
    options = apply_default_options(options)

    url = URI.join(
      @gcs_url,
      ERB::Util.url_encode("/#{bucket}/"), ERB::Util.url_encode(object_name)
    )

    url.query = query_for_signed_url(
      sign(string_that_will_be_signed(url, options)),
      options
    )

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

  # Look for environment variable which stores service_account.
  def look_for_environment_variables
    unless ENV["GOOGLE_CLOUD_KEYFILE"].nil?
      return File.read(ENV["GOOGLE_CLOUD_KEYFILE"])
    end

    ENV["GOOGLE_CLOUD_KEYFILE_JSON"]
  end

  # Signs the string with the given private key.
  def sign(string)
    @key.sign OpenSSL::Digest::SHA256.new, string
  end

  def apply_default_options(options)
    {
      method: "GET", content_md5: nil,
      content_type: nil,
      expires: Time.now.utc.to_i + (options[:valid_for] || 300).to_i,
      google_access_id: @credentials["client_email"]
    }.merge(options)
  end

  def string_that_will_be_signed(url, options)
    [
      options[:method],
      options[:content_md5],
      options[:content_type],
      options[:expires].to_i,
      url.path
    ].join "\n"
  end

  # Escapes and generates query string for actual result.
  def query_for_signed_url(signature, options)
    query = {
      "GoogleAccessId" => options[:google_access_id],
      "Expires" => options[:expires].to_i,
      "Signature" => Base64.strict_encode64(signature),
      "response-content-disposition" => options[:response_content_disposition],
      "response-content-type" => options[:response_content_type]
    }.reject { |_, v| v.nil? }

    URI.encode_www_form(query)
  end

  # raised When GcsSigner could not find service_account JSON file.
  class AuthError < StandardError
  end
end
