# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'ops',
  title: 'Disk usage above 85%',
  description: 'Volume /data on db-primary is at 87%',
  level: 'warning',
  event_type: 'monitor.disk'
)
