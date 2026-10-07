# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Public URL: https://{subdomain}.{domain}/{path_prefix}/{artifact_uuid}
  # Prefer ARTIFACT_CDN_* env vars or Rails credentials (see docs/CDN.md).
  # config.cdn_subdomain = ENV.fetch("ARTIFACT_CDN_SUBDOMAIN", nil)
  # config.cdn_domain = ENV.fetch("ARTIFACT_CDN_DOMAIN", nil)
  # config.cdn_path_prefix = ENV.fetch("ARTIFACT_CDN_PATH_PREFIX", "recording_studio_artifacts")
  # config.cdn_public_base_url = ENV.fetch("ARTIFACT_CDN_PUBLIC_BASE_URL", nil) # optional override

  # Cloudflare R2 (S3-compatible). Hosts should also add `gem "aws-sdk-s3"`.
  # config.cdn_r2_account_id = ENV.fetch("ARTIFACT_CDN_R2_ACCOUNT_ID", nil)
  # config.cdn_r2_access_key_id = ENV.fetch("ARTIFACT_CDN_R2_ACCESS_KEY_ID", nil)
  # config.cdn_r2_secret_access_key = ENV.fetch("ARTIFACT_CDN_R2_SECRET_ACCESS_KEY", nil)
  # config.cdn_r2_bucket = ENV.fetch("ARTIFACT_CDN_R2_BUCKET", nil)
  # config.cdn_r2_endpoint = ENV.fetch("ARTIFACT_CDN_R2_ENDPOINT", nil)
  # config.cdn_r2_region = ENV.fetch("ARTIFACT_CDN_R2_REGION", "auto")

  # Optional Cloudflare cache purge after overwrite.
  # config.cdn_cloudflare_zone_id = ENV.fetch("ARTIFACT_CDN_CLOUDFLARE_ZONE_ID", nil)
  # config.cdn_cloudflare_api_token = ENV.fetch("ARTIFACT_CDN_CLOUDFLARE_API_TOKEN", nil)

  # config.cdn_publish_queue = :default
  # config.cdn_cache_control = "public, max-age=300, stale-while-revalidate=60"
end
