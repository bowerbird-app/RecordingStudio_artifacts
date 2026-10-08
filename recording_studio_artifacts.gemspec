# frozen_string_literal: true

require_relative "lib/recording_studio_artifacts/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_artifacts"
  spec.version     = RecordingStudioArtifacts::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_artifacts"
  spec.summary     = "CDN artifact publisher for Recording Studio addons (Cloudflare R2)"
  spec.description = "A Rails engine that publishes cached HTML/JSON/YAML artifacts to Cloudflare R2 " \
                     "with stable public URLs for third-party Recording Studio gems."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_artifacts"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_artifacts/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "aws-sdk-s3", "~> 1"
end
