# frozen_string_literal: true

require 'trigv'

client = Trigv::Client.new

client.send_event(
  channel: 'orders',
  title: 'New order #1042',
  description: '£89.00 — 2 items, paid via Stripe',
  level: 'info',
  event_type: 'woocommerce.order.created',
  idempotency_key: 'wc-order-1042'
)
