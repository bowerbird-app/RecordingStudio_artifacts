# frozen_string_literal: true

require "test_helper"

class CdnPublishIntegrationTest < ActiveSupport::TestCase
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
end
