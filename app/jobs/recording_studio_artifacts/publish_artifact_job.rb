# frozen_string_literal: true

module RecordingStudioArtifacts
  class PublishArtifactJob < ActiveJob::Base
    queue_as { RecordingStudioArtifacts.configuration.cdn_publish_queue || :default }

    retry_on StandardError, attempts: 5

    def perform(artifact_id)
      artifact = Artifact.find_by(id: artifact_id)
      return if artifact.blank?

      result = Services::PublishArtifact.call(artifact: artifact)
      raise result.error if result.failure?
    end
  end
end
