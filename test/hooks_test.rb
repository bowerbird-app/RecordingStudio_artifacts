# frozen_string_literal: true

require "test_helper"

class HooksTest < Minitest::Test
  def test_template_does_not_ship_a_copied_hooks_class
    refute File.exist?(File.expand_path("../lib/gem_template/hooks.rb", __dir__))
    refute defined?(GemTemplate::Hooks)
  end

  def test_configuration_hooks_are_core_recording_studio_hooks
    configuration = GemTemplate::Configuration.new

    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_engine_runs_addon_hooks_through_configuration
    called = false
    GemTemplate.configuration.hooks.after_initialize { called = true }

    initializer = GemTemplate::Engine.initializers.find do |entry|
      entry.name == "gem_template.after_initialize"
    end
    initializer.block.call(Object.new)

    assert called
  ensure
    GemTemplate.configuration.hooks.clear!
  end
end
