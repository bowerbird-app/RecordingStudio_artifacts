# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_artifacts/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_copies_engine_migrations_in_order_with_increasing_versions
    with_destination do |destination|
      messages = copy_migrations(destination)

      files = migration_files(destination)
      assert_equal 2, files.size
      assert_includes messages, "Found 2 migration(s) to install:"
      assert_includes messages, "\nRun 'bin/rails db:migrate' to apply the migrations."

      create_file = files.find { |path| path.end_with?("create_recording_studio_artifacts.rb") }
      revision_file = files.find { |path| path.include?("add_revision_and_purge_fields") }
      assert create_file
      assert revision_file
      assert_operator version_of(create_file), :<, version_of(revision_file)
      assert_includes File.read(create_file), "create_table :recording_studio_artifacts"
      assert_includes File.read(revision_file), "t.integer :revision"
      assert_includes messages, "  create  db/migrate/#{File.basename(create_file)}"
    end
  end

  def test_skips_migrations_that_already_exist_unless_asked_to_copy_again
    with_destination do |destination|
      copy_migrations(destination)
      original_files = migration_files(destination)

      skipped = copy_migrations(destination)
      assert_equal original_files, migration_files(destination)
      assert_includes skipped, "  skip  create_recording_studio_artifacts.rb (already exists)"
      assert_includes skipped, "  skip  add_revision_and_purge_fields_to_recording_studio_artifacts.rb (already exists)"

      copy_migrations(destination, skip_existing: false)
      files = migration_files(destination)
      assert_equal 4, files.size

      creates = files.select { |path| path.end_with?("create_recording_studio_artifacts.rb") }
      revisions = files.select { |path| path.include?("add_revision_and_purge_fields") }
      assert_equal 2, creates.size
      assert_equal 2, revisions.size
      assert_operator version_of(creates.max), :<, version_of(revisions.max)
      assert_operator version_of(original_files.max), :<, version_of(creates.max)
    end
  end

  def test_reports_when_the_engine_has_no_migrations
    with_destination do |destination|
      empty_source = Dir.mktmpdir
      begin
        missing = copy_migrations(destination, source_root: empty_source)
        assert_includes missing, "No migrations found in RecordingStudioArtifacts engine."
        assert_empty migration_files(destination)

        FileUtils.mkdir_p(File.join(empty_source, "db/migrate"))
        empty = copy_migrations(destination, source_root: empty_source)
        assert_includes empty, "No migrations found in RecordingStudioArtifacts engine."
        assert_empty migration_files(destination)
      ensure
        FileUtils.remove_entry(empty_source)
      end
    end
  end

  private

  def with_destination
    Dir.mktmpdir do |destination|
      FileUtils.mkdir_p(File.join(destination, "db/migrate"))
      yield destination
    end
  end

  def copy_migrations(destination, source_root: nil, skip_existing: true)
    generator = generator_for(destination, source_root: source_root, skip_existing: skip_existing)
    messages = []
    generator.stub(:say, ->(message, _color = nil) { messages << message }) do
      generator.copy_migrations
    end
    messages
  end

  def generator_for(destination, source_root:, skip_existing:)
    generator_class = RecordingStudioArtifacts::Generators::MigrationsGenerator
    if source_root
      generator_class = Class.new(generator_class)
      generator_class.source_root(source_root)
    end

    generator_class.new([], { skip_existing: skip_existing }, destination_root: destination)
  end

  def migration_files(destination)
    Dir.glob(File.join(destination, "db/migrate/*.rb"))
  end

  def version_of(path)
    File.basename(path).split("_", 2).first.to_i
  end
end
