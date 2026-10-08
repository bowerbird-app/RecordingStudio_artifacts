# frozen_string_literal: true

class AddRevisionAndPurgeFieldsToRecordingStudioArtifacts < ActiveRecord::Migration[8.1]
  def change
    change_table :recording_studio_artifacts, bulk: true do |t|
      t.integer :revision, null: false, default: 0
      t.text :purge_error
      t.datetime :purged_at
    end
  end
end
