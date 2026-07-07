# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'general',
  title: 'Hello from Ruby'
)
