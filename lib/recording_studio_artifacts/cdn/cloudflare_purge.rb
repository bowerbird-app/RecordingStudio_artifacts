# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RecordingStudioArtifacts
  module Cdn
    # Purges Cloudflare cached URLs after an overwrite so consumers see fresh content.
    class CloudflarePurge
      API_BASE = "https://api.cloudflare.com/client/v4"

      def initialize(
        zone_id: Credentials.cloudflare_zone_id,
        api_token: Credentials.cloudflare_api_token
      )
        @zone_id = zone_id
        @api_token = api_token
      end

      def purge_urls(urls) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        list = Array(urls).compact_blank
        return { purged: [] } if list.empty?
        raise ArgumentError, "Cloudflare zone id and API token are required to purge" unless configured?

        uri = URI.parse("#{API_BASE}/zones/#{@zone_id}/purge_cache")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_token}"
        request["Content-Type"] = "application/json"
        request.body = { files: list }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        payload = JSON.parse(response.body)
        unless response.is_a?(Net::HTTPSuccess) && payload["success"]
          raise "Cloudflare purge failed: #{payload['errors'] || response.body}"
        end

        { purged: list, result: payload["result"] }
      end

      def configured?
        @zone_id.present? && @api_token.present?
      end
    end
  end
end
