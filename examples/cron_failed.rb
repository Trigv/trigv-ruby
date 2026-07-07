# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'ops',
  title: 'Nightly backup failed',
  description: 'pg_dump exited with code 1 on db-primary',
  level: 'error',
  event_type: 'cron.failed'
)
