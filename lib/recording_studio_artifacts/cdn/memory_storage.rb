# frozen_string_literal: true

require "digest"

module RecordingStudioArtifacts
  module Cdn
    # In-memory R2 stand-in for tests and local dummy publish without credentials.
    class MemoryStorage
      def initialize
        @objects = {}
        @purges = []
      end

      attr_reader :objects, :purges

      def put_object(key:, body:, content_type:, cache_control:, metadata: {})
        @objects[key] = {
          body: body.to_s,
          content_type: content_type,
          cache_control: cache_control,
          metadata: metadata.transform_keys(&:to_s),
          updated_at: Time.now.utc
        }
        { etag: Digest::SHA256.hexdigest(body.to_s)[0, 32], key: key }
      end

      def delete_object(key:)
        removed = @objects.delete(key)
        { deleted: !removed.nil?, key: key }
      end

      def purge_urls(urls)
        list = Array(urls)
        @purges.concat(list)
        { purged: list }
      end

      def read(key)
        @objects[key]
      end

      def clear!
        @objects.clear
        @purges.clear
      end
    end
  end
end
