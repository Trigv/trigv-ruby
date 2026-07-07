# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'agents',
  title: 'Research task completed',
  description: 'Summarised 12 sources on Q3 market trends (run #7f3a)',
  level: 'success',
  event_type: 'agent.task.completed',
  delivery_urgency: 'time_sensitive'
)
