# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CdnHomeDocsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "cdn-home-docs@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
    RecordingStudioArtifacts::Artifact.delete_all
    storage = RecordingStudioArtifacts.configuration.cdn_storage
    storage.clear! if storage.respond_to?(:clear!)
  end

  test "home documents R2 CDN wiring for host engineers" do
    get root_path
    assert_response :success

    assert_includes response.body, "RecordingStudioArtifacts"
    assert_includes response.body, "ARTIFACT_CDN_SUBDOMAIN"
    assert_includes response.body, "ARTIFACT_CDN_R2_BUCKET"
    assert_includes response.body, "ARTIFACT_CDN_CLOUDFLARE_ZONE_ID"
    assert_includes response.body, "cdn_subdomain"
    assert_includes response.body, "cdn_r2_access_key_id"
    assert_includes response.body, "MemoryStorage"
    assert_includes response.body, "RecordingStudioArtifacts.publish"
    assert_match(%r{https://\{subdomain\}\.\{domain\}/\{path_prefix\}/\{artifact_uuid\}}, response.body)
    assert_includes response.body, "config.*"
    assert_includes response.body, "credentials.dig"
  end

  test "home live demo publish and update keep stable URL" do
    get root_path(demo: "publish")
    assert_response :redirect
    follow_redirect!
    assert_response :success

    artifact = RecordingStudioArtifacts::Artifact.order(created_at: :desc).first
    assert artifact
    first_url = artifact.public_url
    assert_match(%r{\Ahttps://artifacts\.example\.test/recording_studio_artifacts/[0-9a-f-]{36}\z}, first_url)
    assert_includes response.body, first_url
    assert_includes response.body, "published"

    get root_path(demo: "update")
    assert_response :redirect
    follow_redirect!
    assert_response :success

    artifact.reload
    assert_equal first_url, artifact.public_url
    assert_includes response.body, "updated"
    assert_equal 1, RecordingStudioArtifacts::Artifact.count
  end
end
