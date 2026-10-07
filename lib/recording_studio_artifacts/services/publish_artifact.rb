# frozen_string_literal: true

module RecordingStudioArtifacts
  module Services
    # Uploads an Artifact body to Cloudflare R2 and optionally purges Cloudflare cache.
    #
    # Always writes the same object key (`{path_prefix}/{artifact_uuid}`) so public URLs
    # stay stable across content updates.
    class PublishArtifact < RecordingStudio::Services::BaseService
      def initialize(artifact:, storage: nil, purger: nil)
        super()
        @artifact = artifact
        @storage = storage
        @purger = purger
      end

      private

      attr_reader :artifact

      def perform # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return failure("artifact is required") if artifact.blank?
        return failure("artifact body is blank") if artifact.body.blank?
        return failure("artifact content_type is blank") if artifact.content_type.blank?
        return failure("CDN public base URL is not configured") unless Cdn.public_base_configured?

        key = artifact.object_key.presence || Cdn.object_key(artifact.id)
        public_url = artifact.public_url.presence || Cdn.public_url(artifact.id)
        artifact.mark_uploading!(object_key: key, public_url: public_url)

        put_result = upload(key)
        purge_result = purge(public_url)
        artifact.mark_published!(key: key, etag: put_result[:etag], public_url: public_url)

        success(
          artifact: artifact,
          key: key,
          public_url: public_url,
          etag: put_result[:etag],
          purged: purge_result[:purged]
        )
      rescue StandardError => e
        artifact.mark_failed!(e.message) if artifact.respond_to?(:mark_failed!)
        failure(e)
      end

      def upload(key)
        storage.put_object(
          key: key,
          body: artifact.body,
          content_type: artifact.content_type,
          cache_control: Cdn.cache_control,
          metadata: {
            "artifact-id" => artifact.id.to_s,
            "artifact-format" => artifact.format.to_s
          }.compact
        )
      end

      def storage
        @storage ||= RecordingStudioArtifacts.configuration.cdn_storage || default_storage
      end

      def default_storage
        return Cdn::R2Client.new if Cdn::Credentials.r2_configured?

        raise ArgumentError,
              "CDN R2 credentials are not configured. Set ARTIFACT_CDN_R2_* env vars " \
              "or Rails credentials under recording_studio_artifacts.cdn, " \
              "or assign config.cdn_storage for tests."
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
        { artifact_id: artifact&.id, format: artifact&.format }
      end
    end
  end
end
