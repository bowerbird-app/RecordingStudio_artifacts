# frozen_string_literal: true

module RecordingStudioArtifacts
  # Cloudflare R2 publish helpers for stable public artifact URLs.
  #
  # Default public URL shape:
  #   https://{subdomain}.{domain}/{path_prefix}/{artifact_uuid}
  #
  # Object keys match the path section so overwrites keep the URL forever.
  module Cdn
    DEFAULT_PATH_PREFIX = "recording_studio_artifacts"
    DEFAULT_CACHE_CONTROL = "public, max-age=300, stale-while-revalidate=60"

    module_function

    def path_prefix
      prefix = RecordingStudioArtifacts.configuration.cdn_path_prefix.presence || DEFAULT_PATH_PREFIX
      prefix.to_s.delete_prefix("/").delete_suffix("/")
    end

    def object_key(artifact_uuid)
      "#{path_prefix}/#{artifact_uuid}"
    end

    def object_path(artifact_uuid)
      "/#{object_key(artifact_uuid)}"
    end

    def public_base_url
      Credentials.public_base_url.presence || assembled_public_base_url
    end

    def public_base_configured?
      public_base_url.present?
    end

    def public_url(artifact_uuid)
      base = public_base_url
      return if base.blank?

      "#{base.delete_suffix('/')}#{object_path(artifact_uuid)}"
    end

    def cache_control
      RecordingStudioArtifacts.configuration.cdn_cache_control.presence || DEFAULT_CACHE_CONTROL
    end

    def assembled_public_base_url
      subdomain = Credentials.subdomain
      domain = Credentials.domain
      return if subdomain.blank? || domain.blank?

      "https://#{subdomain}.#{domain}"
    end

    # Resolves host-owned R2 / public DNS settings from config, ENV, then credentials.
    #
    # ENV names mirror Embeddable's +EMBED_CDN_*+ pattern as +ARTIFACT_CDN_*+.
    module Credentials
      ENV_MAP = {
        subdomain: "ARTIFACT_CDN_SUBDOMAIN",
        domain: "ARTIFACT_CDN_DOMAIN",
        path_prefix: "ARTIFACT_CDN_PATH_PREFIX",
        public_base_url: "ARTIFACT_CDN_PUBLIC_BASE_URL",
        r2_account_id: "ARTIFACT_CDN_R2_ACCOUNT_ID",
        r2_access_key_id: "ARTIFACT_CDN_R2_ACCESS_KEY_ID",
        r2_secret_access_key: "ARTIFACT_CDN_R2_SECRET_ACCESS_KEY",
        r2_bucket: "ARTIFACT_CDN_R2_BUCKET",
        r2_endpoint: "ARTIFACT_CDN_R2_ENDPOINT",
        r2_region: "ARTIFACT_CDN_R2_REGION",
        cloudflare_zone_id: "ARTIFACT_CDN_CLOUDFLARE_ZONE_ID",
        cloudflare_api_token: "ARTIFACT_CDN_CLOUDFLARE_API_TOKEN"
      }.freeze

      CONFIG_MAP = {
        subdomain: :cdn_subdomain,
        domain: :cdn_domain,
        path_prefix: :cdn_path_prefix,
        public_base_url: :cdn_public_base_url,
        r2_account_id: :cdn_r2_account_id,
        r2_access_key_id: :cdn_r2_access_key_id,
        r2_secret_access_key: :cdn_r2_secret_access_key,
        r2_bucket: :cdn_r2_bucket,
        r2_endpoint: :cdn_r2_endpoint,
        r2_region: :cdn_r2_region,
        cloudflare_zone_id: :cdn_cloudflare_zone_id,
        cloudflare_api_token: :cdn_cloudflare_api_token
      }.freeze

      CREDENTIAL_KEYS = CONFIG_MAP.keys.freeze

      module_function

      def fetch(key)
        key = key.to_sym
        from_config(key).presence || from_env(key).presence || from_credentials(key).presence
      end

      def subdomain = fetch(:subdomain)
      def domain = fetch(:domain)
      def path_prefix = fetch(:path_prefix)
      def public_base_url = fetch(:public_base_url)
      def r2_account_id = fetch(:r2_account_id)
      def r2_access_key_id = fetch(:r2_access_key_id)
      def r2_secret_access_key = fetch(:r2_secret_access_key)
      def r2_bucket = fetch(:r2_bucket)
      def r2_endpoint = fetch(:r2_endpoint).presence || derived_r2_endpoint
      def r2_region = fetch(:r2_region).presence || "auto"
      def cloudflare_zone_id = fetch(:cloudflare_zone_id)
      def cloudflare_api_token = fetch(:cloudflare_api_token)

      def r2_configured?
        r2_bucket.present? &&
          r2_access_key_id.present? &&
          r2_secret_access_key.present? &&
          r2_endpoint.present?
      end

      def cloudflare_purge_configured?
        cloudflare_zone_id.present? && cloudflare_api_token.present?
      end

      def derived_r2_endpoint
        account_id = r2_account_id_without_endpoint_lookup
        return if account_id.blank?

        "https://#{account_id}.r2.cloudflarestorage.com"
      end

      def r2_account_id_without_endpoint_lookup
        from_config(:r2_account_id).presence ||
          from_env(:r2_account_id).presence ||
          from_credentials(:r2_account_id).presence
      end

      def from_config(key)
        attr = CONFIG_MAP.fetch(key)
        RecordingStudioArtifacts.configuration.public_send(attr)
      rescue NoMethodError
        nil
      end

      def from_env(key)
        ENV.fetch(ENV_MAP.fetch(key), nil).to_s.strip.presence
      end

      def from_credentials(key)
        return unless defined?(Rails) && Rails.application.respond_to?(:credentials)

        Rails.application.credentials.dig(:recording_studio_artifacts, :cdn, key)
      rescue ActiveSupport::EncryptedFile::MissingKeyError, ArgumentError
        nil
      end
    end
  end
end
