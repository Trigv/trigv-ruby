# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

result = client.send_event(
  channel: 'deploys',
  title: 'Production deploy complete',
  description: 'Build #42 succeeded in 38s (commit abc1234)',
  level: 'success',
  delivery_urgency: 'standard',
  event_type: 'deploy.completed',
  idempotency_key: 'deploy-prod-42'
)

puts result.event.public_id
