# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @configuration = RecordingStudioArtifacts.configuration
    @config_snapshot = @configuration.to_h
    @cdn_credentials = RecordingStudioArtifacts::Cdn::Credentials
    @env_map = @cdn_credentials::ENV_MAP
    @path_prefix = RecordingStudioArtifacts::Cdn.path_prefix
    @public_base_url = RecordingStudioArtifacts::Cdn.public_base_url
    @example_public_url = RecordingStudioArtifacts::Cdn.public_url("11111111-2222-3333-4444-555555555555")
    @storage = @configuration.cdn_storage
    @using_memory_storage = @storage.is_a?(RecordingStudioArtifacts::Cdn::MemoryStorage)
    @master_key_present =
      ENV["RAILS_MASTER_KEY"].to_s.strip.present? ||
      File.exist?(Rails.root.join("config/master.key"))

    return if handle_demo_action!

    load_demo_artifact!
  end

  private

  def handle_demo_action!
    case params[:demo]
    when "publish"
      result = RecordingStudioArtifacts.publish(
        body: sample_body("published"),
        content_type: "text/html; charset=utf-8",
        format: "html",
        source: { gem: "dummy", label: "home#index demo" },
        synchronous: true,
        storage: @storage,
        purger: @configuration.cdn_purger
      )
      redirect_with_demo_result!(result, notice: "Published sample artifact (MemoryStorage overwrite path).")
      true
    when "update"
      artifact = RecordingStudioArtifacts::Artifact.order(created_at: :desc).first
      if artifact.blank?
        redirect_to root_path, alert: "Publish a sample artifact first."
        return true
      end

      result = RecordingStudioArtifacts.update(
        id: artifact.id,
        body: sample_body("updated"),
        content_type: "text/html; charset=utf-8",
        synchronous: true,
        storage: @storage,
        purger: @configuration.cdn_purger
      )
      redirect_with_demo_result!(result, notice: "Updated same object key — public URL unchanged.")
      true
    else
      false
    end
  end

  def redirect_with_demo_result!(result, notice:)
    if result.failure?
      redirect_to root_path, alert: result.error.to_s
    else
      redirect_to root_path(artifact_id: result.value[:artifact].id), notice: notice
    end
  end

  def load_demo_artifact!
    @artifact =
      if params[:artifact_id].present?
        RecordingStudioArtifacts::Artifact.find_by(id: params[:artifact_id])
      else
        RecordingStudioArtifacts::Artifact.order(created_at: :desc).first
      end
    return if @artifact.blank? || !@storage.respond_to?(:read)

    @stored_object = @storage.read(@artifact.object_key) if @artifact.object_key.present?
    @purge_count = @storage.purges.size if @storage.respond_to?(:purges)
  end

  def sample_body(label)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
        <head><meta charset="utf-8"><title>Dummy artifact</title></head>
        <body><p>Dummy CDN artifact (#{label}) at #{Time.current.iso8601}</p></body>
      </html>
    HTML
  end
end
