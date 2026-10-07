# frozen_string_literal: true

module RecordingStudioArtifacts
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioArtifacts

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioArtifacts.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_artifacts_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_artifacts_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    # Run before_initialize hooks
    initializer "recording_studio_artifacts.before_initialize",
                before: "recording_studio_artifacts.load_config" do |_app|
      RecordingStudioArtifacts.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_artifacts.load_config" do |app|
      # Load config/recording_studio_artifacts.yml via Rails config_for if present
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_artifacts)
          rescue StandardError
            nil
          end
          RecordingStudioArtifacts.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError => _e
          # ignore load errors; host app can provide initializer overrides
        end
      end

      # Merge Rails.application.config.x.recording_studio_artifacts if present
      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_artifacts)
        xcfg = app.config.x.recording_studio_artifacts
        if xcfg.respond_to?(:to_h)
          RecordingStudioArtifacts.configuration.merge!(xcfg.to_h)
        else
          begin
            # try converting OrderedOptions
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioArtifacts.configuration.merge!(hash) if hash&.any?
          rescue StandardError => _e
            # ignore
          end
        end
      end

      # Run on_configuration hooks after config is loaded
      RecordingStudioArtifacts.configuration.hooks.run(:on_configuration, RecordingStudioArtifacts.configuration)
    end

    # Run after_initialize hooks
    initializer "recording_studio_artifacts.after_initialize", after: "recording_studio_artifacts.load_config" do |_app|
      RecordingStudioArtifacts.configuration.hooks.run(:after_initialize, self)
    end

    # Apply model extensions when models are loaded
    initializer "recording_studio_artifacts.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioArtifacts::Engine.apply_model_extensions(model)
        end
      end
    end

    # Apply controller extensions
    initializer "recording_studio_artifacts.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioArtifacts::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
