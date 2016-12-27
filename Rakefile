# frozen_string_literal: true

desc "Run console attached to the development state of gem"
task :console do
  require_relative "./lib/gcs_signer"
  require "pry"
  ARGV.clear
  Pry.start
end

desc "Run Rubocop code lints"
task :rubocop do
  sh "bundle exec rubocop -c ./.rubocop.yml"
end
