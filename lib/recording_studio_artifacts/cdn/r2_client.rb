# frozen_string_literal: true

module RecordingStudioArtifacts
  module Cdn
    # Cloudflare R2 uploader (S3-compatible). Depends on +aws-sdk-s3+ (gemspec runtime).
    class R2Client
      def initialize(
        endpoint: Credentials.r2_endpoint,
        region: Credentials.r2_region,
        bucket: Credentials.r2_bucket,
        access_key_id: Credentials.r2_access_key_id,
        secret_access_key: Credentials.r2_secret_access_key
      )
        @endpoint = endpoint
        @region = region
        @bucket = bucket
        @access_key_id = access_key_id
        @secret_access_key = secret_access_key
      end

      def put_object(key:, body:, content_type:, cache_control:, metadata: {})
        response = client.put_object(
          bucket: @bucket,
          key: key,
          body: body,
          content_type: content_type,
          cache_control: cache_control,
          metadata: stringify_metadata(metadata)
        )
        { etag: response.etag.to_s.delete('"').presence, key: key }
      end

      def delete_object(key:)
        client.delete_object(bucket: @bucket, key: key)
        { deleted: true, key: key }
      end

      private

      def client # rubocop:disable Metrics/MethodLength
        @client ||= begin
          require "aws-sdk-s3"
          Aws::S3::Client.new(
            access_key_id: @access_key_id,
            secret_access_key: @secret_access_key,
            endpoint: @endpoint,
            region: @region,
            force_path_style: true
          )
        end
      rescue LoadError
        raise LoadError, "aws-sdk-s3 is required to publish artifacts to Cloudflare R2. " \
                         "It is declared as a runtime dependency of recording_studio_artifacts; " \
                         "run bundle install."
      end

      def stringify_metadata(metadata)
        metadata.each_with_object({}) do |(key, value), result|
          next if value.nil?

          result[key.to_s] = value.to_s
        end
      end
    end
  end
end
