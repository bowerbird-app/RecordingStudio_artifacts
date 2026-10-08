# frozen_string_literal: true

require "recording_studio"
require "recording_studio_artifacts/version"
require "recording_studio_artifacts/engine"
require "recording_studio_artifacts/configuration"
require "recording_studio_artifacts/cdn"
require "recording_studio_artifacts/cdn/memory_storage"
require "recording_studio_artifacts/cdn/r2_client"
require "recording_studio_artifacts/cdn/cloudflare_purge"
require "recording_studio_artifacts/services/publish_artifact"
require "recording_studio_artifacts/services/create_or_update_artifact"
require "recording_studio_artifacts/services/remove_cdn_object"
require "recording_studio_artifacts/services/unpublish_artifact"
require "recording_studio_artifacts/capabilities/example"

module RecordingStudioArtifacts
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Consumer API: create an artifact and publish its body to Cloudflare R2.
    #
    # @example
    #   result = RecordingStudioArtifacts.publish(
    #     body: "<html>...</html>",
    #     content_type: "text/html; charset=utf-8",
    #     format: "html",
    #     source: { gem: "recording_studio_embeddable", token: "..." }
    #   )
    #   result.value[:public_url]
    #
    def publish(**)
      Services::CreateOrUpdateArtifact.call(**)
    end

    # Consumer API: update an existing artifact body and re-publish to the same URL.
    def update(id:, **)
      Services::CreateOrUpdateArtifact.call(id: id, **)
    end

    # Consumer API: delete the R2 object, purge the public URL, and destroy the row.
    #
    # Artifacts are public bearer URLs — unpublish removes the object; it does not
    # grant access control. See docs/CDN.md.
    def unpublish(id:, **)
      Services::UnpublishArtifact.call(id: id, **)
    end
  end
end
