# frozen_string_literal: true

module RecordingStudioArtifacts
  module Services
    # Removes an artifact from R2 (and purges its public URL), then destroys the row.
    #
    # Semantics: unpublish **destroys** the Artifact record. There is no unpublished
    # status. Callers that need the id afterward must store it before calling.
    class UnpublishArtifact < RecordingStudio::Services::BaseService
      def initialize(id:, storage: nil, purger: nil)
        super()
        @id = id
        @storage = storage
        @purger = purger
      end

      private

      def perform # rubocop:disable Metrics/MethodLength
        return failure("id is required") if @id.blank?

        artifact = Artifact.find(@id)
        remove_result = RemoveCdnObject.call(
          artifact: artifact,
          storage: @storage,
          purger: @purger
        )
        return remove_result if remove_result.failure?

        destroy_without_double_cleanup!(artifact)
        success(unpublish_payload(remove_result))
      rescue ActiveRecord::RecordNotFound, StandardError => e
        failure(e)
      end

      def destroy_without_double_cleanup!(artifact)
        artifact.skip_cdn_cleanup = true
        artifact.destroy!
      end

      def unpublish_payload(remove_result)
        {
          id: @id,
          key: remove_result.value[:key],
          public_url: remove_result.value[:public_url],
          deleted: remove_result.value[:deleted],
          purged: remove_result.value[:purged],
          destroyed: true
        }
      end

      def service_args
        { id: @id }
      end
    end
  end
end
