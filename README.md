# gcs-signer

Simple signed URL generator for Google Cloud Storage.

## Features

* No network connection required to generate signed URL.
* Can read JSON service-account credentials from environment variables. So it can be used with [google-cloud-ruby](https://github.com/GoogleCloudPlatform/google-cloud-ruby) without additional configurations.

## Installation

```shell
gem install gcs-signer
```

## Usage

### Authentication

If you already configured `GOOGLE_APPLICATION_CREDENTIALS` for google-cloud-ruby gem, just

```ruby
signer = GcsSigner.new
```

You can also set `GOOGLE_CLOUD_KEYFILE_JSON` environment varialble to the content of service-account.json.

```ruby
puts ENV["GOOGLE_CLOUD_KEYFILE_JSON"]
# => { "type": "service_account", ...
signer = GcsSigner.new
```

or you can give path of the service account file, or contents of it without using environment variables.

```ruby
signer = GcsSigner.new path: "/home/leo/path/to/service_account.json"

signer = GcsSigner.new keyfile_json: '{ "type": "service_account", ...'
```

### Signing URL

`#sign_url` to generate signed URL.

```ruby
# The signed URL is valid for 5 minutes by default.
signer.sign_url "bucket-name", "path/to/object"

# You can specify timestamps or how many seconds the signed URL is valid for.
signer.sign_url "bucket-name", "object-name",
                expires: Time.new(2016, 12, 26, 14, 31, 48)

signer.sign_url "bucket-name", "object_name", valid_for: 600

# If you use AcriveSupport in your project, you can use some sugar like:
signer.sign_url "bucket", "object", valid_for: 45.minutes
signer.sign_url "bucket", "object", expires_at: 5.minutes.from_now

# You can set response_content_disposition and response_content_type to change response headers.
signer.sign_url "bucket", "object", response_content_type: "video/mp4"
signer.sign_url "bucket", "object", response_content_disposition: "attachment; filename=video.mp4"

# You can use V4 signing if you prefer longer URL
signer.sign_url "bucket", "object", version: :v4
```

## License

gcs-signer is distributed under the MIT License.
