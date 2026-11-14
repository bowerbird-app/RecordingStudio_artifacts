# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_artifacts.gemspec
gemspec

# recording_studio and flat_pack are not published to RubyGems; resolve the gemspec pins from GitHub.
# Core 6.14 requires flat_pack >= 0.1.315.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.374"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.14.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "pg", "~> 1.1"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
