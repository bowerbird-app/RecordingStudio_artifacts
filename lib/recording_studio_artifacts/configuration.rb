# frozen_string_literal: true

module RecordingStudioArtifacts
  class Configuration
    attr_accessor(
      :api_key,
      :enable_feature_x,
      :timeout,
      :cdn_subdomain,
      :cdn_domain,
      :cdn_path_prefix,
      :cdn_public_base_url,
      :cdn_cache_control,
      :cdn_r2_account_id,
      :cdn_r2_access_key_id,
      :cdn_r2_secret_access_key,
      :cdn_r2_bucket,
      :cdn_r2_endpoint,
      :cdn_r2_region,
      :cdn_cloudflare_zone_id,
      :cdn_cloudflare_api_token,
      :cdn_publish_queue,
      :cdn_storage,
      :cdn_purger
    )
    attr_reader :hooks

    def initialize # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      @api_key = ENV.fetch("RECORDING_STUDIO_ARTIFACTS_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @cdn_subdomain = nil
      @cdn_domain = nil
      @cdn_path_prefix = "recording_studio_artifacts"
      @cdn_public_base_url = nil
      @cdn_cache_control = "public, max-age=300, stale-while-revalidate=60"
      @cdn_r2_account_id = nil
      @cdn_r2_access_key_id = nil
      @cdn_r2_secret_access_key = nil
      @cdn_r2_bucket = nil
      @cdn_r2_endpoint = nil
      @cdn_r2_region = "auto"
      @cdn_cloudflare_zone_id = nil
      @cdn_cloudflare_api_token = nil
      @cdn_publish_queue = :default
      @cdn_storage = nil
      @cdn_purger = nil
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h # rubocop:disable Metrics/MethodLength
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        cdn_subdomain: cdn_subdomain,
        cdn_domain: cdn_domain,
        cdn_path_prefix: cdn_path_prefix,
        cdn_public_base_url: cdn_public_base_url,
        cdn_r2_bucket: cdn_r2_bucket,
        cdn_publish_queue: cdn_publish_queue,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
