# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/object/blank"
require "securerandom"
require "active_job"
require_relative "../app/jobs/recording_studio_artifacts/publish_artifact_job"

class CdnPublishTest < Minitest::Test
  class FakeArtifact
    attr_accessor :id, :body, :content_type, :format, :source, :metadata,
                  :status, :object_key, :public_url, :etag, :published_at, :last_error,
                  :revision, :purge_error, :purged_at

    def initialize(id: SecureRandom.uuid, body: "<html>v1</html>", content_type: "text/html", revision: 1)
      @id = id
      @body = body
      @content_type = content_type
      @format = "html"
      @source = {}
      @metadata = {}
      @status = "pending"
      @revision = revision
      @object_key = RecordingStudioArtifacts::Cdn.object_key(id)
      @public_url = RecordingStudioArtifacts::Cdn.public_url(id)
    end

    def published?
      status == "published" && published_at.present?
    end

    def reload
      self
    end

    def with_lock
      yield
    end

    def mark_uploading!(object_key:, public_url:)
      @status = "uploading"
      @object_key = object_key
      @public_url = public_url
      @last_error = nil
    end

    def mark_published!(key:, public_url:, etag: nil)
      @status = "published"
      @object_key = key
      @public_url = public_url
      @etag = etag
      @published_at = Time.now.utc
      @last_error = nil
    end

    def mark_failed!(message)
      @status = "failed"
      @last_error = message.to_s
    end

    def mark_purged!
      @purged_at = Time.now.utc
      @purge_error = nil
    end

    def record_purge_error!(message)
      @purge_error = message.to_s
      @purged_at = nil
    end
  end

  class RaisingPurger
    def purge_urls(_urls)
      raise "Cloudflare purge failed: boom"
    end
  end

  class LoadErrorStorage
    def put_object(**)
      raise LoadError, "cannot load such file -- aws-sdk-s3"
    end

    def delete_object(key:)
      { deleted: true, key: key }
    end
  end

  def setup
    RecordingStudioArtifacts.reset_configuration!
    @storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
    RecordingStudioArtifacts.configure do |config|
      config.cdn_subdomain = "artifacts"
      config.cdn_domain = "example.test"
      config.cdn_path_prefix = "recording_studio_artifacts"
      config.cdn_storage = @storage
      config.cdn_purger = @storage
    end
  end

  def teardown
    RecordingStudioArtifacts.reset_configuration!
  end

  def test_public_url_uses_subdomain_domain_path_prefix_and_uuid
    uuid = "11111111-2222-3333-4444-555555555555"
    url = RecordingStudioArtifacts::Cdn.public_url(uuid)

    assert_equal "https://artifacts.example.test/recording_studio_artifacts/#{uuid}", url
    assert_equal "recording_studio_artifacts/#{uuid}", RecordingStudioArtifacts::Cdn.object_key(uuid)
    assert_equal "/recording_studio_artifacts/#{uuid}", RecordingStudioArtifacts::Cdn.object_path(uuid)
  end

  def test_public_base_url_override_wins_over_assembled_host
    RecordingStudioArtifacts.configuration.cdn_public_base_url = "https://cdn.override.test"
    uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    assert_equal "https://cdn.override.test/recording_studio_artifacts/#{uuid}",
                 RecordingStudioArtifacts::Cdn.public_url(uuid)
  end

  def test_publish_overwrites_same_object_key_and_purges
    artifact = FakeArtifact.new(body: "<html>v1</html>")
    first = publish(artifact)
    assert first.success?, first.error

    key = artifact.object_key
    assert_equal "recording_studio_artifacts/#{artifact.id}", key
    assert_equal "https://artifacts.example.test/#{key}", first.value[:public_url]
    assert_includes @storage.read(key)[:body], "v1"
    assert_includes @storage.purges, first.value[:public_url]

    artifact.body = "<html>v2 updated</html>"
    artifact.revision = 2
    second = publish(artifact, expected_revision: 2)
    assert second.success?, second.error

    assert_equal key, second.value[:key]
    assert_equal first.value[:public_url], second.value[:public_url]
    assert_equal 1, @storage.objects.size
    assert_includes @storage.read(key)[:body], "v2 updated"
    refute_includes @storage.read(key)[:body], "v1"
    assert_equal 2, @storage.purges.size
    assert_equal "published", artifact.status
  end

  def test_stale_revision_skips_without_flipping_status_or_etag
    artifact = FakeArtifact.new(body: "<html>current</html>", revision: 3)
    artifact.status = "published"
    artifact.etag = "etag-current"
    artifact.published_at = Time.now.utc

    result = publish(artifact, expected_revision: 1)
    assert result.success?, result.error
    assert result.value[:skipped]
    assert_equal "published", artifact.status
    assert_equal "etag-current", artifact.etag
    assert_nil @storage.read(artifact.object_key)
  end

  def test_purge_failure_keeps_artifact_published
    artifact = FakeArtifact.new(body: "<html>ok</html>", revision: 1)
    result = RecordingStudioArtifacts::Services::PublishArtifact.call(
      artifact: artifact,
      expected_revision: 1,
      storage: @storage,
      purger: RaisingPurger.new
    )

    assert result.success?, result.error
    refute result.value[:skipped]
    assert_equal "published", artifact.status
    assert_match(/purge failed/i, artifact.purge_error.to_s)
    assert_nil artifact.purged_at
    assert_equal "published", artifact.status
    assert result.value[:purge_error]
    assert_empty result.value[:purged]
    assert @storage.read(artifact.object_key)
  end

  def test_load_error_marks_failed_not_stuck_uploading
    artifact = FakeArtifact.new(revision: 1)
    result = RecordingStudioArtifacts::Services::PublishArtifact.call(
      artifact: artifact,
      expected_revision: 1,
      storage: LoadErrorStorage.new,
      purger: @storage
    )

    assert result.failure?
    assert_match(/aws-sdk-s3/i, result.error.to_s)
    assert_equal "failed", artifact.status
    refute_equal "uploading", artifact.status
    assert_match(/aws-sdk-s3/i, artifact.last_error)
  end

  def test_memory_storage_delete_object_removes_key
    @storage.put_object(
      key: "k",
      body: "x",
      content_type: "text/plain",
      cache_control: "public",
      metadata: {}
    )
    assert @storage.read("k")
    @storage.delete_object(key: "k")
    assert_nil @storage.read("k")
  end

  def test_module_publish_api_delegates_to_create_or_update
    assert_respond_to RecordingStudioArtifacts, :publish
    assert_respond_to RecordingStudioArtifacts, :update
    assert_respond_to RecordingStudioArtifacts, :unpublish
  end

  def test_docs_warn_about_public_bearer_urls
    readme = File.read(File.expand_path("../README.md", __dir__))
    docs = File.read(File.expand_path("../docs/CDN.md", __dir__))

    [readme, docs].each do |text|
      assert_match(/bearer/i, text)
      assert_match(/not access control/i, text)
      assert_match(/embargo/i, text)
      assert_match(/cookie domain/i, text)
    end
  end

  def test_credentials_env_map_documents_artifact_cdn_vars
    expected = %w[
      ARTIFACT_CDN_SUBDOMAIN
      ARTIFACT_CDN_DOMAIN
      ARTIFACT_CDN_PATH_PREFIX
      ARTIFACT_CDN_PUBLIC_BASE_URL
      ARTIFACT_CDN_R2_ACCOUNT_ID
      ARTIFACT_CDN_R2_ACCESS_KEY_ID
      ARTIFACT_CDN_R2_SECRET_ACCESS_KEY
      ARTIFACT_CDN_R2_BUCKET
      ARTIFACT_CDN_R2_ENDPOINT
      ARTIFACT_CDN_R2_REGION
      ARTIFACT_CDN_CLOUDFLARE_ZONE_ID
      ARTIFACT_CDN_CLOUDFLARE_API_TOKEN
    ]
    assert_equal expected.sort, RecordingStudioArtifacts::Cdn::Credentials::ENV_MAP.values.sort
  end

  def test_credentials_prefer_config_then_env
    RecordingStudioArtifacts.configuration.cdn_domain = "from-config.test"
    ENV["ARTIFACT_CDN_DOMAIN"] = "from-env.test"
    assert_equal "from-config.test", RecordingStudioArtifacts::Cdn::Credentials.domain

    RecordingStudioArtifacts.configuration.cdn_domain = nil
    assert_equal "from-env.test", RecordingStudioArtifacts::Cdn::Credentials.domain
  ensure
    ENV.delete("ARTIFACT_CDN_DOMAIN")
  end

  def test_r2_endpoint_derived_from_account_id
    RecordingStudioArtifacts.configuration.cdn_r2_account_id = "abc123account"
    assert_equal "https://abc123account.r2.cloudflarestorage.com",
                 RecordingStudioArtifacts::Cdn::Credentials.r2_endpoint
  end

  def test_cloudflare_purge_noops_without_urls
    purger = RecordingStudioArtifacts::Cdn::CloudflarePurge.new(zone_id: "zone", api_token: "token")
    assert_equal({ purged: [] }, purger.purge_urls([]))
  end

  def test_publish_requires_public_base_configuration
    RecordingStudioArtifacts.configuration.cdn_subdomain = nil
    RecordingStudioArtifacts.configuration.cdn_domain = nil
    RecordingStudioArtifacts.configuration.cdn_public_base_url = nil
    artifact = FakeArtifact.new
    artifact.public_url = nil

    result = publish(artifact)
    assert result.failure?
    assert_match(/public base URL/i, result.error.to_s)
  end

  def test_cdn_docs_list_every_env_key
    docs = File.read(File.expand_path("../docs/CDN.md", __dir__))
    RecordingStudioArtifacts::Cdn::Credentials::ENV_MAP.each_value do |env_name|
      assert_includes docs, env_name
    end
  end

  def test_gemspec_declares_aws_sdk_s3
    gemspec = File.read(File.expand_path("../recording_studio_artifacts.gemspec", __dir__))
    assert_includes gemspec, 'spec.add_dependency "aws-sdk-s3"'
  end

  def test_publish_job_enqueues_after_transaction_commit
    assert RecordingStudioArtifacts::PublishArtifactJob.enqueue_after_transaction_commit
  end

  private

  def publish(artifact, expected_revision: artifact.revision)
    RecordingStudioArtifacts::Services::PublishArtifact.call(
      artifact: artifact,
      expected_revision: expected_revision,
      storage: @storage,
      purger: @storage
    )
  end
end
