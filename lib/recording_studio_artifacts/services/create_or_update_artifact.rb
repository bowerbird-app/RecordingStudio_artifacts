# frozen_string_literal: true

module RecordingStudioArtifacts
  module Services
    # Creates or updates an Artifact record and enqueues (or runs) R2 publish.
    class CreateOrUpdateArtifact < RecordingStudio::Services::BaseService
      def initialize(
        body:,
        content_type:,
        id: nil,
        format: nil,
        source: nil,
        metadata: nil,
        synchronous: false,
        storage: nil,
        purger: nil
      )
        super()
        @id = id
        @body = body
        @content_type = content_type
        @format = format
        @source = source
        @metadata = metadata
        @synchronous = synchronous
        @storage = storage
        @purger = purger
      end

      private

      def perform
        return failure("body is required") if @body.nil?
        return failure("content_type is required") if @content_type.to_s.strip.empty?

        artifact = persist_artifact!
        @synchronous ? publish_synchronously(artifact) : enqueue_publish(artifact)
      rescue StandardError => e
        failure(e)
      end

      def persist_artifact!
        artifact = find_or_initialize
        assign_attributes!(artifact)
        artifact.save!
        assign_url_fields!(artifact)
        artifact
      end

      def publish_synchronously(artifact)
        publish_result = run_publish(artifact)
        return publish_result if publish_result.failure?

        success(synchronous_payload(artifact, publish_result))
      end

      def run_publish(artifact)
        PublishArtifact.call(
          artifact: artifact,
          expected_revision: artifact.revision,
          storage: @storage,
          purger: @purger
        )
      end

      def synchronous_payload(artifact, publish_result)
        {
          artifact: artifact.reload,
          public_url: artifact.public_url,
          enqueued: false,
          publish: publish_result.value
        }
      end

      def enqueue_publish(artifact)
        PublishArtifactJob.perform_later(artifact.id, artifact.revision)
        success(
          artifact: artifact,
          public_url: artifact.public_url || Cdn.public_url(artifact.id),
          enqueued: true,
          publish: nil
        )
      end

      def find_or_initialize
        if @id.present?
          Artifact.find(@id)
        else
          Artifact.new
        end
      end

      def assign_attributes!(artifact) # rubocop:disable Metrics/AbcSize
        artifact.body = @body
        artifact.content_type = @content_type.to_s
        artifact.format = (@format.presence || Artifact.infer_format(@content_type)).to_s
        artifact.source = (@source || artifact.source || {}).to_h
        artifact.metadata = (artifact.metadata || {}).to_h.merge((@metadata || {}).to_h)
        artifact.status = "pending"
        artifact.bump_revision!
      end

      def assign_url_fields!(artifact)
        artifact.object_key = Cdn.object_key(artifact.id)
        artifact.public_url = Cdn.public_url(artifact.id) if Cdn.public_base_configured?
        artifact.save! if artifact.changed?
      end

      def service_args
        { id: @id, format: @format, synchronous: @synchronous }
      end
    end
  end
end
