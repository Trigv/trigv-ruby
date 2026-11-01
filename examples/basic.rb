# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

result = client.send_event(
  channel: 'general',
  title: 'Hello from Ruby'
)

puts result.request_id
