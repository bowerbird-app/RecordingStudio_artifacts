# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 extracts Object#stub into the minitest-mock gem. The dummy
  # bundle does not load that gem; only the gem suite stubs methods.
end
require "rails"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_artifacts"
