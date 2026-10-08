# frozen_string_literal: true

module RecordingStudioArtifacts
  class PublishArtifactJob < ActiveJob::Base
    # Rails 8.1 defaults this to false; enqueue only after the Artifact row commits
    # so a rolled-back create/update cannot leave a job racing a missing row.
    self.enqueue_after_transaction_commit = true

    queue_as { RecordingStudioArtifacts.configuration.cdn_publish_queue || :default }

    # Retry upload/transport failures. After attempts are exhausted, re-raise so the
    # failure is visible (a missing row must not disappear into a silent no-op).
    retry_on StandardError, attempts: 5 do |_job, error|
      raise error
    end

    def perform(artifact_id, revision)
      artifact = Artifact.find(artifact_id)

      result = Services::PublishArtifact.call(
        artifact: artifact,
        expected_revision: revision
      )
      return if result.success? && result.value[:skipped]
      return if result.success?

      raise result.error
    end
  end
end
