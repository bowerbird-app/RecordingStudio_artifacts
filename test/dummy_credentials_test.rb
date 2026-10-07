# frozen_string_literal: true

require "test_helper"
require "yaml"
require "active_support/encrypted_file"

class DummyCredentialsTest < Minitest::Test
  PLACEHOLDER = "dev_placeholder"

  CDN_CREDENTIAL_KEYS = %w[
    subdomain
    domain
    path_prefix
    public_base_url
    r2_account_id
    r2_access_key_id
    r2_secret_access_key
    r2_bucket
    r2_endpoint
    r2_region
    cloudflare_zone_id
    cloudflare_api_token
  ].freeze

  def test_only_dummy_credentials_file_is_committed
    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- '*.yml.enc'`.split("\n").reject(&:empty?)
    end

    assert_equal ["test/dummy/config/credentials.yml.enc"], tracked
  end

  def test_encrypted_credentials_file_is_present
    path = dummy_credentials_path
    assert File.exist?(path), "Expected #{path} so new gems reuse the shared dummy credentials"
    assert File.size(path).positive?
  end

  def test_master_key_is_gitignored_and_untracked
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))
    assert_includes gitignore, "test/dummy/config/master.key"
    assert_includes gitignore, "config/master.key"

    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- config/master.key test/dummy/config/master.key`.strip
    end
    assert_equal "", tracked, "master.key must not be committed"
  end

  def test_dummy_credentials_decrypt_when_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    parsed = YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: dummy_credentials_path,
        key_path: dummy_master_key_path,
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )

    assert_operator parsed.fetch("secret_key_base").to_s.length, :>=, 64
    legacy_key = ["gem", "template"].join("_")
    api_key = parsed.dig("recording_studio_artifacts", "api_key") || parsed.dig(legacy_key, "api_key")
    assert_equal PLACEHOLDER, api_key
    assert_equal PLACEHOLDER, parsed.dig("smtp", "user_name")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "password")
    assert_equal PLACEHOLDER, parsed.dig("aws", "access_key_id")
    assert_equal PLACEHOLDER, parsed.dig("aws", "secret_access_key")

    # CDN host keys (optional until shared credentials are refreshed with R2 keys).
    # Prefer ARTIFACT_CDN_* env vars; credentials dig path is documented in docs/CDN.md.
    cdn = parsed.dig("recording_studio_artifacts", "cdn")
    return unless cdn.is_a?(Hash)

    CDN_CREDENTIAL_KEYS.each do |key|
      assert cdn.key?(key), "Expected recording_studio_artifacts.cdn.#{key} in shared dummy credentials"
    end
  end

  def test_cdn_credential_env_names_are_documented
    docs = File.read(File.expand_path("../docs/CDN.md", __dir__))
    RecordingStudioArtifacts::Cdn::Credentials::ENV_MAP.each_value do |env_name|
      assert_includes docs, env_name
    end
  end

  private

  def dummy_credentials_path
    File.expand_path("../test/dummy/config/credentials.yml.enc", __dir__)
  end

  def dummy_master_key_path
    File.expand_path("../test/dummy/config/master.key", __dir__)
  end

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(dummy_master_key_path)
  end
end
