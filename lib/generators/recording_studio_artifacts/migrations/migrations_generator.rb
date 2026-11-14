# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioArtifacts
  module Generators
    # Generator to install RecordingStudioArtifacts migrations into the host application.
    #
    # Usage:
    #   rails generate recording_studio_artifacts:migrations
    #
    # Options:
    #   --skip-existing  Skip migrations that already exist in the host app
    #
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../../../..", __dir__)

      desc "Copy RecordingStudioArtifacts migrations to your application"

      class_option :skip_existing, type: :boolean, default: true,
                                   desc: "Skip migrations that already exist (based on name, ignoring timestamp)"

      def copy_migrations
        migrations_dir = File.join(self.class.source_root, "db", "migrate")

        unless File.directory?(migrations_dir)
          say "No migrations found in RecordingStudioArtifacts engine.", :yellow
          return
        end

        migration_files = Dir.glob(File.join(migrations_dir, "*.rb"))

        if migration_files.empty?
          say "No migrations found in RecordingStudioArtifacts engine.", :yellow
          return
        end

        say "Found #{migration_files.size} migration(s) to install:", :green

        migration_files.each do |source_path|
          filename = File.basename(source_path)
          # Extract migration name without timestamp (e.g., "create_recording_studio_artifacts_pages.rb")
          migration_name = filename.sub(/^\d+_/, "")

          if options[:skip_existing] && migration_exists?(migration_name)
            say "  skip  #{migration_name} (already exists)", :yellow
            next
          end

          # Host timestamps must increase even when several files are copied in the same second.
          # Equal timestamps sort by name, which would run add_revision before create_table.
          timestamp = next_migration_number
          destination_filename = "#{timestamp}_#{migration_name}"
          destination_path = File.join("db/migrate", destination_filename)

          copy_file source_path, destination_path
          say "  create  #{destination_path}", :green
        end

        say "\nRun 'bin/rails db:migrate' to apply the migrations.", :green
      end

      private

      def migration_exists?(migration_name)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
      end

      def next_migration_number
        candidate = Time.now.utc.strftime("%Y%m%d%H%M%S")
        candidate = candidate.next while migration_number_taken?(candidate)
        issued_migration_numbers << candidate
        ActiveRecord::Migration.next_migration_number(candidate)
      end

      def migration_number_taken?(candidate)
        issued_migration_numbers.include?(candidate) ||
          Dir.glob(File.join(destination_root.to_s, "db/migrate", "#{candidate}_*.rb")).any?
      end

      def issued_migration_numbers
        @issued_migration_numbers ||= []
      end
    end
  end
end
