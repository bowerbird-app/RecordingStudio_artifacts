# frozen_string_literal: true

require "test_helper"
require "securerandom"
require_relative "support/artifact_database"

class ArtifactLifecycleTest < Minitest::Test
  def setup
    ArtifactDatabase.prepare!
    RecordingStudioArtifacts.reset_configuration!
    @storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
    RecordingStudioArtifacts.configure do |config|
      config.cdn_subdomain = "artifacts"
      config.cdn_domain = "example.test"
      config.cdn_path_prefix = "recording_studio_artifacts"
      config.cdn_storage = @storage
      config.cdn_purger = @storage
      config.cdn_publish_queue = :cdn
    end
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    RecordingStudioArtifacts::Artifact.delete_all
  end

  def teardown
    RecordingStudioArtifacts::Artifact.delete_all
    RecordingStudioArtifacts.reset_configuration!
  end

  def test_publish_update_and_unpublish_round_trip_on_one_url
    published = publish_body(
      "<html>v1</html>",
      source: { gem: "demo" },
      metadata: { label: "first" }
    )
    assert published.success?, published.error

    artifact = published.value[:artifact].reload
    key = "recording_studio_artifacts/#{artifact.id}"
    url = "https://artifacts.example.test/#{key}"

    assert_equal url, published.value[:public_url]
    assert_equal false, published.value[:enqueued]
    assert_equal url, published.value[:publish][:public_url]
    assert_equal false, published.value[:publish][:skipped]
    assert_equal [url], published.value[:publish][:purged]
    assert_equal "published", artifact.status
    assert_equal 1, artifact.revision
    assert_equal "html", artifact.format
    assert_equal key, artifact.object_key
    assert_equal url, artifact.public_url
    assert artifact.published?
    assert artifact.published_at
    assert artifact.purged_at
    assert_nil artifact.purge_error
    assert_nil artifact.last_error
    assert_equal({ "gem" => "demo" }, artifact.source)
    assert_equal({ "label" => "first" }, artifact.metadata)
    stored = @storage.read(key)
    assert_equal "<html>v1</html>", stored[:body]
    assert_equal "text/html; charset=utf-8", stored[:content_type]
    assert_equal "public, max-age=300, stale-while-revalidate=60", stored[:cache_control]
    assert_equal artifact.id, stored[:metadata]["artifact-id"]
    assert_equal "html", stored[:metadata]["artifact-format"]
    assert_equal "1", stored[:metadata]["artifact-revision"]
    assert_equal [url], @storage.purges

    updated = update_body(artifact.id, "<html>v2</html>", metadata: { extra: "second" })
    assert updated.success?, updated.error
    artifact.reload

    assert_equal url, updated.value[:public_url]
    assert_equal key, artifact.object_key
    assert_equal 2, artifact.revision
    assert_equal "published", artifact.status
    assert_equal({ "gem" => "demo" }, artifact.source)
    assert_equal({ "label" => "first", "extra" => "second" }, artifact.metadata)
    assert_equal 1, @storage.objects.size
    assert_equal "<html>v2</html>", @storage.read(key)[:body]
    assert_equal [url, url], @storage.purges

    removed = RecordingStudioArtifacts.unpublish(id: artifact.id, storage: @storage, purger: @storage)
    assert removed.success?, removed.error
    assert_equal true, removed.value[:destroyed]
    assert_equal true, removed.value[:deleted]
    assert_equal key, removed.value[:key]
    assert_equal url, removed.value[:public_url]
    assert_equal [url], removed.value[:purged]
    assert_nil @storage.read(key)
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  def test_publish_infers_format_and_rejects_missing_body_or_content_type
    json = publish_body('{"ok":true}', content_type: "application/json", format: :omit)
    assert json.success?, json.error
    assert_equal "json", json.value[:artifact].format

    png = publish_body("png", content_type: "image/png", format: :omit)
    assert png.success?, png.error
    assert_equal "png", png.value[:artifact].format

    assert_equal "bin", RecordingStudioArtifacts::Artifact.infer_format("")
    assert_equal "html", RecordingStudioArtifacts::Artifact.infer_format("Text/HTML; charset=utf-8")

    missing_body = RecordingStudioArtifacts.publish(
      body: nil,
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert missing_body.failure?
    assert_equal "body is required", missing_body.error

    blank_type = RecordingStudioArtifacts.publish(
      body: "x",
      content_type: "  ",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert blank_type.failure?
    assert_equal "content_type is required", blank_type.error
    assert_equal 2, RecordingStudioArtifacts::Artifact.count
  end

  def test_update_and_unpublish_of_an_unknown_id_fail_without_changing_storage
    published = publish_body("<html>keep</html>")
    assert published.success?, published.error
    key = published.value[:artifact].object_key

    missing = update_body(SecureRandom.uuid, "<html>nope</html>")
    assert missing.failure?
    assert_equal "<html>keep</html>", @storage.read(key)[:body]

    unpublished = RecordingStudioArtifacts.unpublish(id: SecureRandom.uuid, storage: @storage, purger: @storage)
    assert unpublished.failure?
    assert_equal "<html>keep</html>", @storage.read(key)[:body]

    blank = RecordingStudioArtifacts.unpublish(id: " ", storage: @storage, purger: @storage)
    assert blank.failure?
    assert_equal "id is required", blank.error
  end

  def test_failed_update_leaves_the_published_object_in_place
    published = publish_body("<html>v1</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key

    rejected = RecordingStudioArtifacts.update(
      id: artifact.id,
      body: nil,
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert rejected.failure?
    assert_equal "body is required", rejected.error
    assert_equal 1, artifact.reload.revision
    assert_equal "<html>v1</html>", @storage.read(key)[:body]
  end

  def test_publish_without_a_public_base_fails_and_marks_the_row_failed
    RecordingStudioArtifacts.configuration.cdn_subdomain = nil
    RecordingStudioArtifacts.configuration.cdn_domain = nil
    RecordingStudioArtifacts.configuration.cdn_public_base_url = nil

    result = publish_body("<html>hidden</html>")
    assert result.failure?
    assert_match(/public base URL/i, result.error.to_s)

    artifact = RecordingStudioArtifacts::Artifact.order(:created_at).last
    assert_equal "pending", artifact.status
    assert_nil artifact.last_error
    assert_nil @storage.read(artifact.object_key)
  end

  def test_publish_without_storage_or_r2_credentials_fails
    RecordingStudioArtifacts.configuration.cdn_storage = nil

    result = publish_body("<html>nowhere</html>", storage: nil, purger: nil)
    assert result.failure?
    assert_match(/not configured/i, result.error.to_s)
    assert_equal "failed", RecordingStudioArtifacts::Artifact.order(:created_at).last.status
    assert_empty @storage.objects
  end

  def test_storage_errors_mark_the_artifact_failed
    storage = Object.new
    def storage.put_object(**)
      raise "disk full"
    end

    result = publish_body("<html>full</html>", storage: storage)
    assert result.failure?
    assert_match(/disk full/, result.error.to_s)

    artifact = RecordingStudioArtifacts::Artifact.order(:created_at).last
    assert_equal "failed", artifact.status
    assert_match(/disk full/, artifact.last_error)
  end

  def test_unpublish_without_deletable_storage_keeps_the_row_and_the_object
    published = publish_body("<html>stay</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key

    result = RecordingStudioArtifacts.unpublish(id: artifact.id, storage: Object.new, purger: @storage)
    assert result.failure?
    assert_match(/not configured/i, result.error.to_s)
    assert_equal "<html>stay</html>", @storage.read(key)[:body]
    assert RecordingStudioArtifacts::Artifact.exists?(artifact.id)
  end

  def test_unpublish_of_a_row_with_no_object_key_still_removes_the_row
    artifact = RecordingStudioArtifacts::Artifact.create!(
      body: "note",
      content_type: "text/plain",
      format: "txt"
    )

    result = RecordingStudioArtifacts.unpublish(id: artifact.id, storage: @storage, purger: @storage)
    assert result.success?, result.error
    assert_equal false, result.value[:deleted]
    assert_nil result.value[:key]
    assert_empty result.value[:purged]
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  def test_destroy_deletes_the_stored_object
    published = publish_body("<html>gone</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key

    artifact.destroy!

    assert_nil @storage.read(key)
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  def test_destroy_removes_the_row_when_storage_cannot_delete
    published = publish_body("<html>orphan</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key
    RecordingStudioArtifacts.configuration.cdn_storage = Object.new

    artifact.destroy!

    assert_equal "<html>orphan</html>", @storage.read(key)[:body]
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  def test_async_publish_uploads_when_the_job_runs_on_the_configured_queue
    result = publish_body("<html>later</html>", synchronous: false)
    assert result.success?, result.error
    assert_equal true, result.value[:enqueued]
    assert_nil result.value[:publish]

    artifact = result.value[:artifact]
    assert_equal "pending", artifact.status
    assert_equal 1, artifact.revision
    assert_nil @storage.read(artifact.object_key)

    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs
    assert_equal 1, enqueued.size
    assert_equal RecordingStudioArtifacts::PublishArtifactJob, enqueued.first[:job]
    assert_equal [artifact.id, 1], enqueued.first[:args]
    assert_equal "cdn", enqueued.first[:queue]

    RecordingStudioArtifacts::PublishArtifactJob.new.perform(artifact.id, 1)

    assert_equal "published", artifact.reload.status
    assert_equal "<html>later</html>", @storage.read(artifact.object_key)[:body]
    assert_includes @storage.purges, artifact.public_url
  end

  def test_publish_job_skips_a_stale_revision_and_raises_when_publish_fails
    published = publish_body("<html>v1</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key
    updated = update_body(artifact.id, "<html>v2</html>")
    assert updated.success?, updated.error
    etag = artifact.reload.etag

    RecordingStudioArtifacts::PublishArtifactJob.new.perform(artifact.id, 1)

    artifact.reload
    assert_equal "published", artifact.status
    assert_equal 2, artifact.revision
    assert_equal etag, artifact.etag
    assert_equal "<html>v2</html>", @storage.read(key)[:body]

    RecordingStudioArtifacts.configuration.cdn_subdomain = nil
    RecordingStudioArtifacts.configuration.cdn_domain = nil
    RecordingStudioArtifacts.configuration.cdn_public_base_url = nil
    pending = publish_body("<html>pending</html>", synchronous: false)
    assert pending.success?, pending.error

    error = assert_raises(RuntimeError) do
      RecordingStudioArtifacts::PublishArtifactJob.new.perform(pending.value[:artifact].id, 1)
    end
    assert_match(/public base URL/i, error.message)
    assert_equal "pending", pending.value[:artifact].reload.status
    assert_nil @storage.read(pending.value[:artifact].object_key)

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioArtifacts::PublishArtifactJob.new.perform(SecureRandom.uuid, 1)
    end
  end

  def test_publish_without_a_purger_stores_the_object_and_does_not_purge
    RecordingStudioArtifacts.configuration.cdn_purger = nil

    result = publish_body("<html>cached</html>", purger: nil)
    assert result.success?, result.error
    assert_empty result.value[:publish][:purged]
    assert_nil result.value[:publish][:purge_error]

    artifact = result.value[:artifact].reload
    assert_equal "published", artifact.status
    assert_nil artifact.purged_at
    assert_nil artifact.purge_error
    assert_empty @storage.purges
    assert_equal "<html>cached</html>", @storage.read(artifact.object_key)[:body]
  end

  def test_unpublish_without_storage_or_purge_configuration_keeps_a_stored_row
    published = publish_body("<html>stay</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key
    RecordingStudioArtifacts.configuration.cdn_storage = nil
    RecordingStudioArtifacts.configuration.cdn_purger = nil

    result = RecordingStudioArtifacts.unpublish(id: artifact.id)
    assert result.failure?
    assert_match(/not configured/i, result.error.to_s)
    assert_equal "<html>stay</html>", @storage.read(key)[:body]
    assert RecordingStudioArtifacts::Artifact.exists?(artifact.id)
  end

  def test_unpublish_without_a_purger_still_deletes_the_object
    published = publish_body("<html>drop</html>")
    artifact = published.value[:artifact]
    key = artifact.object_key
    purges_after_publish = @storage.purges.dup
    RecordingStudioArtifacts.configuration.cdn_purger = nil

    result = RecordingStudioArtifacts.unpublish(id: artifact.id, storage: @storage, purger: nil)
    assert result.success?, result.error
    assert_equal true, result.value[:deleted]
    assert_empty result.value[:purged]
    assert_equal purges_after_publish, @storage.purges
    assert_nil @storage.read(key)
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  def test_purge_failure_keeps_the_published_object
    purger = Object.new
    def purger.purge_urls(_urls)
      raise "Cloudflare purge failed: intentional"
    end

    result = publish_body("<html>stays</html>", purger: purger)
    assert result.success?, result.error
    assert_match(/intentional/, result.value[:publish][:purge_error])
    assert_empty result.value[:publish][:purged]

    artifact = result.value[:artifact].reload
    assert_equal "published", artifact.status
    assert_match(/intentional/, artifact.purge_error)
    assert_nil artifact.purged_at
    assert_equal "<html>stays</html>", @storage.read(artifact.object_key)[:body]
  end

  private

  def publish_body(body, **options)
    format = options.key?(:format) ? options.delete(:format) : "html"
    arguments = {
      body: body,
      content_type: options.delete(:content_type) || "text/html; charset=utf-8",
      synchronous: options.fetch(:synchronous, true),
      storage: options.key?(:storage) ? options.delete(:storage) : @storage,
      purger: options.key?(:purger) ? options.delete(:purger) : @storage,
      **options
    }
    arguments[:format] = format unless format == :omit
    RecordingStudioArtifacts.publish(**arguments)
  end

  def update_body(id, body, **rest)
    RecordingStudioArtifacts.update(
      id: id,
      body: body,
      content_type: "text/html; charset=utf-8",
      synchronous: true,
      storage: @storage,
      purger: @storage,
      **rest
    )
  end
end
