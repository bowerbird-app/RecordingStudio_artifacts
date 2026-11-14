# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  # Accessible 0.36+ raises on manage-access until the host names who can be granted.
  config.access_management_actor_scope = ->(_controller) { User.order(:email) }
end
