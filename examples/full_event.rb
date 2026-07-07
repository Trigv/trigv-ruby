# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'deploys',
  title: 'Production deploy complete',
  description: 'Build #42 succeeded in 38s (commit abc1234)',
  image_url: 'https://example.com/build-42.png',
  level: 'success',
  delivery_urgency: 'standard',
  event_type: 'deploy.completed',
  idempotency_key: 'deploy-prod-42'
)
