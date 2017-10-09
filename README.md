# gcs-signer

Simple signed URL generator for Google Cloud Storage.

## Features

* No additional gems required.
* No network connection required to generate signed URL.
* Can read JSON service_account credentials from environment variables. So it can be used with [google-cloud-ruby](https://github.com/GoogleCloudPlatform/google-cloud-ruby) without additional configurations.

## Installation

```shell
gem install gcs-signer
```

```ruby
require 'gcs-signer'
```

## Usage

If you already configured `GOOGLE_CLOUD_KEYFILE` or `GOOGLE_CLOUD_KEYFILE_JSON` for google-cloud-ruby gem, just

```ruby
signer = GcsSigner.new
```

or you can give path of the service_account json file, or contents of it.

```ruby
signer = GcsSigner.new path: "/home/leo/path/to/service_account.json"

signer = GcsSigner.new json_string: '{ "type": "service_account", ...'
```

then `#sign_url` to generate signed URL.

```ruby
# The signed URL is valid for 5 minutes by default.
signer.sign_url "bucket-name", "path/to/object"

# You can specify timestamps or how many seconds the signed URL is valid for.
signer.sign_url "bucket-name", "object-name",
                expires: Time.new(2016, 12, 26, 14, 31, 48)

signer.sign_url "bucket-name", "object_name", valid_for: 600

# If you use AcriveSupport in your project, you can also do some magic like:
signer.sign_url "bucket", "object", valid_for: 45.minutes

# See https://cloud.google.com/storage/docs/access-control/signed-urls
# for other avaliable options.
signer.sign_url "bucket", "object", google_access_id: "sangwon@sha.kr",
                method: "PUT", content_type: "text/plain",
                md5: "beefbeef..."
```

## License

gcs-signer is distributed under the MIT License.
