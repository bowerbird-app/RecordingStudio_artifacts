# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Dummy uses MemoryStorage so publish is exercisable without real R2 keys.
  storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
  config.cdn_storage = storage
  config.cdn_purger = storage
  config.cdn_subdomain = "artifacts"
  config.cdn_domain = "example.test"
  config.cdn_path_prefix = "recording_studio_artifacts"
end
