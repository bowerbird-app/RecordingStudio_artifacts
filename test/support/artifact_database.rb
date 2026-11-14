# frozen_string_literal: true

require "uri"

module ArtifactDatabase
  DATABASE_NAME = "recording_studio_artifacts_gem_test"

  def self.prepare!
    return if @prepared

    require "pg"
    require "active_record"
    require "active_job"

    create_database!
    connect!
    ActiveRecord::Migration.verbose = false
    migrate!
    require_models!
    ActiveJob::Base.queue_adapter = :test
    @prepared = true
  end

  def self.create_database!
    config = pg_config(connection_config.merge(database: "postgres"))
    PG.connect(config).tap do |connection|
      existing = connection.exec_params("SELECT 1 FROM pg_database WHERE datname = $1", [DATABASE_NAME])
      connection.exec(%(CREATE DATABASE "#{DATABASE_NAME}")) if existing.ntuples.zero?
    end.close
  end

  def self.connect!
    ActiveRecord::Base.establish_connection(connection_config.merge(adapter: "postgresql", encoding: "unicode"))
    ActiveRecord::Base.logger = Logger.new(File::NULL)
  end

  def self.migrate!
    return if ActiveRecord::Base.connection.table_exists?(:recording_studio_artifacts)

    migrations_path = File.expand_path("../../db/migrate", __dir__)
    ActiveRecord::MigrationContext.new(migrations_path).migrate
  end

  def self.require_models!
    root = File.expand_path("../..", __dir__)
    require File.join(root, "app/models/recording_studio_artifacts/application_record")
    require File.join(root, "app/models/recording_studio_artifacts/artifact")
    require File.join(root, "app/jobs/recording_studio_artifacts/publish_artifact_job")
  end

  def self.connection_config
    if ENV["DATABASE_URL"].to_s == ""
      {
        host: ENV.fetch("DB_HOST", "localhost"),
        port: ENV.fetch("DB_PORT", "5432").to_i,
        username: ENV.fetch("DB_USER", "postgres"),
        password: ENV.fetch("DB_PASSWORD", "postgres"),
        database: DATABASE_NAME
      }
    else
      uri = URI.parse(ENV.fetch("DATABASE_URL", nil))
      {
        host: uri.host || "localhost",
        port: uri.port || 5432,
        username: URI.decode_www_form_component(uri.user || "postgres"),
        password: uri.password && URI.decode_www_form_component(uri.password),
        database: DATABASE_NAME
      }
    end
  end

  def self.pg_config(config)
    {
      host: config[:host],
      port: config[:port],
      user: config[:username],
      password: config[:password],
      dbname: config[:database]
    }
  end
end
