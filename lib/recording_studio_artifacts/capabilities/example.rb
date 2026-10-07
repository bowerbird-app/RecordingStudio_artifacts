# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    # Example opt-in mixin for addons copied from this template.
    #
    # Host models opt in with:
    #   include RecordingStudio::Capabilities::Example.to(label: "demo")
    #
    # Installing this gem does not enable the mixin on any type. `.to` wraps
    # RecordingStudio::Capabilities.include_for so enablement and options stay
    # on the same factory as core 4.2.0.
    module Example
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:example, **)
      end
    end
  end
end

RecordingStudio.register_capability(
  :example,
  source: RecordingStudio::Capabilities::Example
)
