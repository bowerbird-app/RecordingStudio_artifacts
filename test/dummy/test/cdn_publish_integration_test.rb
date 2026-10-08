# frozen_string_literal: true

require "test_helper"

class CdnPublishIntegrationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @storage = RecordingStudioArtifacts.configuration.cdn_storage
    @storage.clear! if @storage.respond_to?(:clear!)
  end

  test "publish creates artifact with stable URL and overwrite keeps the same key" do
    first = RecordingStudioArtifacts.publish(
      body: "<html><body>one</body></html>",
      content_type: "text/html; charset=utf-8",
      format: "html",
      source: { gem: "dummy", label: "demo" },
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert first.success?, first.error.to_s

    artifact = first.value[:artifact]
    url = first.value[:public_url]
    key = "recording_studio_artifacts/#{artifact.id}"

    assert_match(%r{\Ahttps://artifacts\.example\.test/recording_studio_artifacts/[0-9a-f-]{36}\z}, url)
    assert_equal key, artifact.object_key
    assert_equal "published", artifact.status
    assert_equal 1, artifact.revision
    assert_equal "<html><body>one</body></html>", @storage.read(key)[:body]
    assert_includes @storage.purges, url

    second = RecordingStudioArtifacts.update(
      id: artifact.id,
      body: "<html><body>two</body></html>",
      content_type: "text/html; charset=utf-8",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert second.success?, second.error.to_s

    artifact.reload
    assert_equal url, second.value[:public_url]
    assert_equal key, artifact.object_key
    assert_equal 2, artifact.revision
    assert_equal 1, @storage.objects.size
    assert_equal "<html><body>two</body></html>", @storage.read(key)[:body]
    assert_equal 2, @storage.purges.size
  end

  test "json and yml formats are accepted" do
    json = RecordingStudioArtifacts.publish(
      body: '{"ok":true}',
      content_type: "application/json",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert json.success?, json.error.to_s
    assert_equal "json", json.value[:artifact].format

    yml = RecordingStudioArtifacts.publish(
      body: "ok: true\n",
      content_type: "application/yaml",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert yml.success?, yml.error.to_s
    assert_equal "yml", yml.value[:artifact].format
  end

  test "out of order and stale revision jobs never overwrite a newer revision" do
    result = RecordingStudioArtifacts.publish(
      body: "<html>rev1</html>",
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert result.success?, result.error.to_s
    artifact = result.value[:artifact]
    key = artifact.object_key
    etag_after_first = artifact.etag

    updated = RecordingStudioArtifacts.update(
      id: artifact.id,
      body: "<html>rev2</html>",
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert updated.success?, updated.error.to_s
    artifact.reload
    assert_equal 2, artifact.revision
    etag_after_second = artifact.etag
    assert_equal "<html>rev2</html>", @storage.read(key)[:body]

    stale = RecordingStudioArtifacts::Services::PublishArtifact.call(
      artifact: artifact,
      expected_revision: 1,
      storage: @storage,
      purger: @storage
    )
    assert stale.success?, stale.error.to_s
    assert stale.value[:skipped]

    artifact.reload
    assert_equal "published", artifact.status
    assert_equal 2, artifact.revision
    assert_equal etag_after_second, artifact.etag
    refute_equal etag_after_first, artifact.etag
    assert_equal "<html>rev2</html>", @storage.read(key)[:body]
  end

  test "purge failure keeps artifact published and records purge_error" do
    purger = Object.new
    def purger.purge_urls(_urls)
      raise "Cloudflare purge failed: intentional"
    end

    result = RecordingStudioArtifacts.publish(
      body: "<html>purge-fail</html>",
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: purger
    )
    assert result.success?, result.error.to_s

    artifact = result.value[:artifact].reload
    assert_equal "published", artifact.status
    assert_match(/intentional/, artifact.purge_error.to_s)
    assert_nil artifact.purged_at
    assert @storage.read(artifact.object_key)
    assert result.value[:publish][:purge_error]
  end

  test "unpublish deletes the object and destroys the row" do
    result = RecordingStudioArtifacts.publish(
      body: "<html>gone</html>",
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert result.success?, result.error.to_s
    artifact = result.value[:artifact]
    id = artifact.id
    key = artifact.object_key
    url = artifact.public_url
    assert @storage.read(key)

    unpublished = RecordingStudioArtifacts.unpublish(id: id, storage: @storage, purger: @storage)
    assert unpublished.success?, unpublished.error.to_s
    assert unpublished.value[:destroyed]
    assert_nil @storage.read(key)
    assert_includes @storage.purges, url
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: id)
  end

  test "destroy removes the R2 object" do
    result = RecordingStudioArtifacts.publish(
      body: "<html>destroy-me</html>",
      content_type: "text/html",
      synchronous: true,
      storage: @storage,
      purger: @storage
    )
    assert result.success?, result.error.to_s
    artifact = result.value[:artifact]
    key = artifact.object_key
    assert @storage.read(key)

    artifact.destroy!
    assert_nil @storage.read(key)
    assert_nil RecordingStudioArtifacts::Artifact.find_by(id: artifact.id)
  end

  test "missing artifact raises in the publish job" do
    # Call #perform directly: retry_on StandardError reschedules via the adapter
    # on perform_now, which would hide the raise under the test queue adapter.
    assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioArtifacts::PublishArtifactJob.new.perform(SecureRandom.uuid, 1)
    end
  end

  test "load error marks failed instead of leaving uploading" do
    storage = Object.new
    def storage.put_object(**)
      raise LoadError, "cannot load such file -- aws-sdk-s3"
    end

    result = RecordingStudioArtifacts.publish(
      body: "<html>load-error</html>",
      content_type: "text/html",
      synchronous: true,
      storage: storage,
      purger: @storage
    )
    assert result.failure?
    artifact = RecordingStudioArtifacts::Artifact.order(:created_at).last
    assert_equal "failed", artifact.status
    refute_equal "uploading", artifact.status
    assert_match(/aws-sdk-s3/i, artifact.last_error.to_s)
  end

  test "async publish enqueues job with revision after commit" do
    assert RecordingStudioArtifacts::PublishArtifactJob.enqueue_after_transaction_commit

    assert_enqueued_with(job: RecordingStudioArtifacts::PublishArtifactJob) do
      result = RecordingStudioArtifacts.publish(
        body: "<html>async</html>",
        content_type: "text/html",
        synchronous: false,
        storage: @storage,
        purger: @storage
      )
      assert result.success?, result.error.to_s
      assert result.value[:enqueued]
      artifact = result.value[:artifact]
      assert_equal 1, artifact.revision
    end
  end
end
