# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'deploys',
  title: 'Staging deploy complete',
  description: 'Build #41 passed all checks',
  level: 'success',
  event_type: 'deploy.completed'
)
