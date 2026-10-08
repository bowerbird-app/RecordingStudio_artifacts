# frozen_string_literal: true

module RecordingStudioArtifacts
  module Services
    # Uploads an Artifact body to Cloudflare R2 and optionally purges Cloudflare cache.
    #
    # Always writes the same object key (`{path_prefix}/{artifact_uuid}`) so public URLs
    # stay stable across content updates.
    #
    # Concurrency: serializes per artifact with +with_lock+ (row lock). Jobs carry an
    # +expected_revision+; stale revisions are skipped and never flip status/etag on a
    # newer revision. Purge failures do not fail publish or trigger re-upload.
    class PublishArtifact < RecordingStudio::Services::BaseService # rubocop:disable Metrics/ClassLength
      def initialize(artifact:, expected_revision: nil, storage: nil, purger: nil)
        super()
        @artifact = artifact
        @expected_revision = expected_revision
        @storage = storage
        @purger = purger
      end

      private

      attr_reader :artifact, :expected_revision

      def perform
        return failure("artifact is required") if artifact.blank?
        return failure("CDN public base URL is not configured") unless Cdn.public_base_configured?

        publish_under_lock
      rescue LoadError, StandardError => e
        mark_failed_safely(e)
        failure(e)
      end

      def publish_under_lock # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        put_result = nil
        key = nil
        public_url = nil

        with_artifact_lock do
          artifact.reload if artifact.respond_to?(:reload)

          return stale_success("revision moved before upload") if stale_revision?
          return failure("artifact body is blank") if artifact.body.blank?
          return failure("artifact content_type is blank") if artifact.content_type.blank?

          key = artifact.object_key.presence || Cdn.object_key(artifact.id)
          public_url = artifact.public_url.presence || Cdn.public_url(artifact.id)
          artifact.mark_uploading!(object_key: key, public_url: public_url)

          put_result = upload(key)

          artifact.reload if artifact.respond_to?(:reload)
          return stale_success("revision moved during upload") if stale_revision?

          artifact.mark_published!(key: key, etag: put_result[:etag], public_url: public_url)
        end

        purge_after_publish(public_url, put_result, key)
      end

      def purge_after_publish(public_url, put_result, key)
        purge_result = attempt_purge(public_url)

        success(
          artifact: artifact,
          key: key,
          public_url: public_url,
          etag: put_result[:etag],
          purged: purge_result[:purged],
          purge_error: purge_result[:purge_error],
          skipped: false
        )
      end

      def attempt_purge(public_url)
        return { purged: [], purge_error: nil } if purger.nil? || public_url.blank?

        result = purger.purge_urls([public_url])
        artifact.mark_purged! if artifact.respond_to?(:mark_purged!)
        { purged: result[:purged], purge_error: nil }
      rescue LoadError, StandardError => e
        record_purge_failure(e)
        { purged: [], purge_error: e.message }
      end

      def record_purge_failure(error)
        artifact.record_purge_error!(error.message) if artifact.respond_to?(:record_purge_error!)
        log_purge_failure(error)
        instrument_purge_failure(error)
      end

      def log_purge_failure(error)
        Rails.logger&.warn(
          "[RecordingStudioArtifacts] CDN purge failed after publish " \
          "artifact=#{artifact.id} revision=#{artifact.try(:revision)}: #{error.message}"
        )
      end

      def instrument_purge_failure(error)
        ActiveSupport::Notifications.instrument(
          "purge_failed.recording_studio_artifacts",
          artifact_id: artifact.id,
          revision: artifact.try(:revision),
          error: error.message
        )
      end

      def stale_revision?
        return false if expected_revision.nil?

        artifact.revision.to_i != expected_revision.to_i
      end

      def stale_success(reason)
        success(
          artifact: artifact,
          skipped: true,
          reason: reason,
          expected_revision: expected_revision,
          current_revision: artifact.try(:revision)
        )
      end

      def with_artifact_lock(&)
        if artifact.respond_to?(:with_lock)
          artifact.with_lock(&)
        else
          yield
        end
      end

      def mark_failed_safely(error)
        return unless artifact.respond_to?(:mark_failed!)
        return if artifact.respond_to?(:published?) && artifact.published?

        artifact.mark_failed!(error.message)
      rescue StandardError
        nil
      end

      def upload(key)
        storage.put_object(
          key: key,
          body: artifact.body,
          content_type: artifact.content_type,
          cache_control: Cdn.cache_control,
          metadata: upload_metadata
        )
      end

      def upload_metadata
        {
          "artifact-id" => artifact.id.to_s,
          "artifact-format" => artifact.format.to_s,
          "artifact-revision" => artifact.revision.to_s
        }.compact
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

      def service_args
        {
          artifact_id: artifact&.id,
          format: artifact&.format,
          expected_revision: expected_revision
        }
      end
    end
  end
end
