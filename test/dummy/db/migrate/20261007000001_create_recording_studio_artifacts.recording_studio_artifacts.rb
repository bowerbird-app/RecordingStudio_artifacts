# frozen_string_literal: true

class CreateRecordingStudioArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_artifacts, id: :uuid do |t|
      t.string :format, null: false
      t.string :content_type, null: false
      t.text :body, null: false
      t.jsonb :source, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.string :object_key
      t.string :public_url
      t.string :etag
      t.datetime :published_at
      t.text :last_error

      t.timestamps
    end

    add_index :recording_studio_artifacts, :status
    add_index :recording_studio_artifacts, :object_key, unique: true
    add_index :recording_studio_artifacts, :published_at
  end
end
