# frozen_string_literal: true

require_relative "./lib/gcs_signer/version"

Gem::Specification.new do |s|
  s.name = "gcs-signer"

  s.version = if ENV["TRAVIS"]
                "#{s.version}-#{ENV['TRAVIS_BUILD_NUMBER']}"
              else
                GcsSigner::VERSION
              end

  s.authors = ["Sangwon Yi", "Minku Lee", "Larry Kim"]
  s.email = ["sangwon@sha.kr", "minku@sha.kr", "larry@sha.kr"]
  s.files = Dir["{lib}/**/*", "README.md"]

  s.license = "MIT"
  s.summary = "Simple signed URL generator for Google Cloud Storage."
  s.description = <<DESC
  Simple signed URL generator for Google Cloud Storage.
  No additional gems and API requests required to generate signed URL.
DESC
  s.required_ruby_version = "~> 2.3"
  s.homepage = "https://github.com/shakrmedia/gcs-signer"

  s.add_dependency "addressable", "~> 2.7"

  s.add_development_dependency "pry", "~> 0.11"
  s.add_development_dependency "rake", "~> 12.3"
  s.add_development_dependency "rubocop", "~> 0.57.2"
end
