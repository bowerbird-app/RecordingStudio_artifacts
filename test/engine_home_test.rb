# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch"

class EngineHomeTest < Minitest::Test
  def test_root_responds_ok
    require File.expand_path("../app/controllers/recording_studio_artifacts/application_controller", __dir__)
    require File.expand_path("../app/controllers/recording_studio_artifacts/home_controller", __dir__)

    controller = RecordingStudioArtifacts::HomeController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.set_response!(ActionDispatch::TestResponse.new)
    controller.process(:index)

    assert_equal 200, controller.response.status
    assert_equal "", controller.response.body
  end
end
