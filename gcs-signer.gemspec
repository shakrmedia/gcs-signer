# frozen_string_literal: true
require_relative "./lib/gcs_signer"

Gem::Specification.new do |s|
  s.name = "gcs-signer"
  s.version = GcsSigner::VERSION
  s.version = "#{s.version}-#{ENV['TRAVIS_BUILD_NUMBER']}" if ENV["TRAVIS"]
  s.authors = ["Sangwon Yi", "Minku Lee"]
  s.email = ["sangwon@sha.kr", "minku@sha.kr"]
  s.files = Dir["{lib}/**/*", "README.md"]

  s.license = "MIT"
  s.summary = "Simple signed URL generator for Google Cloud Storage."
  s.description = <<EOF
  Simple signed URL generator for Google Cloud Storage.
  No additional gems and API requests required to generate signed URL.
EOF
  s.required_ruby_version = "~> 2.2"
  s.homepage = "https://github.com/shakrmedia/gcs-signer"

  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "pry", "~> 0.9"
  s.add_development_dependency "rubocop", "~> 0.40.0"
end
