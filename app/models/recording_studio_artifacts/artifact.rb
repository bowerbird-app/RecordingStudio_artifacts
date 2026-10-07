# frozen_string_literal: true

module RecordingStudioArtifacts
  class Artifact < ApplicationRecord
    self.table_name = "recording_studio_artifacts"

    STATUSES = %w[pending uploading published failed].freeze

    FORMAT_BY_CONTENT_TYPE = {
      "text/html" => "html",
      "application/json" => "json",
      "application/yaml" => "yml",
      "application/x-yaml" => "yml",
      "text/yaml" => "yml",
      "text/x-yaml" => "yml",
      "text/plain" => "txt",
      "application/javascript" => "js",
      "text/css" => "css",
      "application/xml" => "xml",
      "text/xml" => "xml"
    }.freeze

    validates :body, presence: true
    validates :content_type, presence: true
    validates :format, presence: true
    validates :status, inclusion: { in: STATUSES }

    before_validation :apply_defaults

    def published?
      status == "published" && published_at.present?
    end

    def mark_uploading!(object_key:, public_url:)
      update!(
        status: "uploading",
        object_key: object_key,
        public_url: public_url,
        last_error: nil
      )
    end

    def mark_published!(key:, public_url:, etag: nil)
      update!(
        status: "published",
        object_key: key,
        public_url: public_url,
        etag: etag,
        published_at: Time.now.utc,
        last_error: nil
      )
    end

    def mark_failed!(message)
      update!(status: "failed", last_error: message.to_s)
    end

    class << self
      def infer_format(content_type)
        base = content_type.to_s.split(";").first.to_s.strip.downcase
        FORMAT_BY_CONTENT_TYPE.fetch(base) do
          extension = base.split("/").last.to_s
          extension.presence || "bin"
        end
      end
    end

    private

    def apply_defaults # rubocop:disable Metrics/AbcSize
      self.status = "pending" if status.blank?
      self.source = {} if source.nil?
      self.metadata = {} if metadata.nil?
      self.format = self.class.infer_format(content_type) if format.blank? && content_type.present?
    end
  end
end
