# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioArtifacts::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(
      cdn_subdomain: "cdn",
      cdn_domain: "example.com",
      cdn_path_prefix: "artifacts",
      cdn_r2_bucket: "bucket"
    )

    assert_equal "cdn", @configuration.cdn_subdomain
    assert_equal "example.com", @configuration.cdn_domain
    assert_equal "artifacts", @configuration.cdn_path_prefix
    assert_equal "bucket", @configuration.cdn_r2_bucket
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", cdn_domain: "ok.test")

    refute_respond_to @configuration, :unknown_key
    assert_equal "ok.test", @configuration.cdn_domain
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:cdn_path_prefix], @configuration.cdn_path_prefix
    assert_equal original[:cdn_publish_queue], @configuration.cdn_publish_queue
  end

  def test_initialize_uses_environment_api_key_and_cdn_defaults
    previous_value = ENV.fetch("RECORDING_STUDIO_ARTIFACTS_API_KEY", nil)
    ENV["RECORDING_STUDIO_ARTIFACTS_API_KEY"] = "env-token"

    configuration = RecordingStudioArtifacts::Configuration.new

    assert_equal "env-token", configuration.api_key
    assert_equal "recording_studio_artifacts", configuration.cdn_path_prefix
    assert_equal :default, configuration.cdn_publish_queue
    assert_equal "auto", configuration.cdn_r2_region
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  ensure
    ENV["RECORDING_STUDIO_ARTIFACTS_API_KEY"] = previous_value
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("cdn_subdomain" => "assets", "cdn_domain" => "host.test")

    assert_equal "assets", @configuration.cdn_subdomain
    assert_equal "host.test", @configuration.cdn_domain
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioArtifacts.configure

    assert_kind_of RecordingStudioArtifacts::Configuration, RecordingStudioArtifacts.configuration
  end
end
