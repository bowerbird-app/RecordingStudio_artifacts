# frozen_string_literal: true

module RecordingStudioArtifacts
  module Services
    # Deletes the R2 object for an artifact and optionally purges its public URL.
    # Used by unpublish and by Artifact destroy so rows never leave silent orphans.
    class RemoveCdnObject < RecordingStudio::Services::BaseService
      def initialize(artifact:, storage: nil, purger: nil)
        super()
        @artifact = artifact
        @storage = storage
        @purger = purger
      end

      private

      attr_reader :artifact

      def perform # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        return failure("artifact is required") if artifact.blank?

        key = artifact.object_key.presence
        public_url = artifact.public_url.presence
        remove_stored_object(key)
        purge_result = purge(public_url)

        success(
          artifact_id: artifact.id,
          key: key,
          public_url: public_url,
          deleted: key.present?,
          purged: purge_result[:purged]
        )
      rescue StandardError => e
        failure(e)
      end

      def remove_stored_object(key)
        return if key.blank?

        unless storage.respond_to?(:delete_object)
          raise ArgumentError,
                "CDN storage is not configured; cannot delete object #{key}. " \
                "Assign config.cdn_storage or R2 credentials before unpublish/destroy."
        end

        storage.delete_object(key: key)
      end

      def storage
        @storage ||= RecordingStudioArtifacts.configuration.cdn_storage || default_storage
      end

      def default_storage
        return Cdn::R2Client.new if Cdn::Credentials.r2_configured?

        nil
      end

      def purger
        @purger ||= RecordingStudioArtifacts.configuration.cdn_purger || default_purger
      end

      def default_purger
        return Cdn::CloudflarePurge.new if Cdn::Credentials.cloudflare_purge_configured?

        nil
      end

      def purge(public_url)
        return { purged: [] } if purger.nil? || public_url.blank?

        purger.purge_urls([public_url])
      end

      def service_args
        { artifact_id: artifact&.id, object_key: artifact&.object_key }
      end
    end
  end
end
