# frozen_string_literal: true

require "test_helper"
require "json"
require "net/http"

class CloudflarePurgeTest < Minitest::Test
  def test_purge_posts_the_urls_and_returns_them
    purger = RecordingStudioArtifacts::Cdn::CloudflarePurge.new(zone_id: "zone-1", api_token: "token-1")
    captured = nil
    response = http_response(
      "200",
      { "success" => true, "result" => { "id" => "purge-1" } }
    )

    result = with_http(response, on_request: ->(request) { captured = request }) do
      purger.purge_urls([
                          "https://artifacts.example.test/recording_studio_artifacts/one",
                          "https://artifacts.example.test/recording_studio_artifacts/two"
                        ])
    end

    assert_equal [
      "https://artifacts.example.test/recording_studio_artifacts/one",
      "https://artifacts.example.test/recording_studio_artifacts/two"
    ], result[:purged]
    assert_equal({ "id" => "purge-1" }, result[:result])
    assert_equal "Bearer token-1", captured["Authorization"]
    assert_equal "application/json", captured["Content-Type"]
    assert_equal "/client/v4/zones/zone-1/purge_cache", captured.path
    assert_equal(
      {
        "files" => [
          "https://artifacts.example.test/recording_studio_artifacts/one",
          "https://artifacts.example.test/recording_studio_artifacts/two"
        ]
      },
      JSON.parse(captured.body)
    )
  end

  def test_purge_raises_when_cloudflare_rejects_the_request
    purger = RecordingStudioArtifacts::Cdn::CloudflarePurge.new(zone_id: "zone-1", api_token: "token-1")
    response = http_response("400", { "success" => false, "errors" => [{ "message" => "invalid zone" }] })

    error = assert_raises(RuntimeError) do
      with_http(response) { purger.purge_urls(["https://artifacts.example.test/one"]) }
    end

    assert_match(/invalid zone/, error.message)
  end

  def test_purge_requires_a_zone_and_token
    purger = RecordingStudioArtifacts::Cdn::CloudflarePurge.new(zone_id: nil, api_token: nil)

    refute purger.configured?
    error = assert_raises(ArgumentError) do
      purger.purge_urls(["https://artifacts.example.test/one"])
    end
    assert_match(/zone id and API token/i, error.message)
  end

  private

  def http_response(code, payload)
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new("1.1", code, "status")
    response.instance_variable_set(:@read, true)
    response.body = payload.to_json
    response
  end

  def with_http(response, on_request: nil, &)
    http = Object.new
    http.define_singleton_method(:request) do |request|
      on_request&.call(request)
      response
    end

    Net::HTTP.stub(:start, lambda { |*args, **kwargs, &http_session|
      assert_equal "api.cloudflare.com", args[0]
      assert_equal 443, args[1]
      assert_equal true, kwargs.fetch(:use_ssl)
      http_session.call(http)
    }, &)
  end
end
