# trigv

Official Trigv SDK for Ruby. Send notification events from scripts, servers, and CI pipelines.

## What Trigv is

Trigv delivers developer notifications to your team's devices. Your backend sends lightweight JSON events; Trigv queues push delivery. Notification title and body are not stored on Trigv servers — metadata only.

## Installation

Add to your Gemfile:

```ruby
gem 'trigv', '~> 0.1'
```

Then run:

```bash
bundle install
```

## Quick start

```ruby
require 'trigv'

client = Trigv::Client.new(api_key: ENV['TRIGV_API_KEY'])

client.send_event(
  channel: 'general',
  title: 'Deploy finished',
  description: 'Build #42 succeeded in 38s'
)
```

## Authentication

Create a workspace API key at [app.trigv.com](https://app.trigv.com). Keys look like `trgv_xxxxxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

```ruby
client = Trigv::Client.new(api_key: 'trgv_your_api_key')
# or set TRIGV_API_KEY in the environment
```

**Do not** send the API key in the JSON body — use the `Authorization: Bearer` header (handled automatically).

## Sending an event

```ruby
result = client.send_event(
  channel: 'general',
  title: 'Cron job failed',
  description: 'Nightly backup did not complete',
  level: 'error',
  event_type: 'cron.failed'
)

puts result.event.public_id
```

## Event options

| Field | Required | Description |
|-------|:--------:|-------------|
| `channel` | Yes | Channel slug (e.g. `general`) |
| `title` | Yes | Notification title |
| `description` | No | Body text |
| `image_url` | No | HTTPS image URL (not stored server-side) |
| `level` | No | `info`, `success`, `warning`, `error` (default: `info`) |
| `delivery_urgency` | No | `standard` or `time_sensitive` (default: `standard`) |
| `event_type` | No | Free-form label (e.g. `deploy.completed`) |
| `idempotency_key` | No | Dedup key per workspace |

## Levels

- `info` — general information (default)
- `success` — completed successfully
- `warning` — attention needed
- `error` — failure or alert

## Delivery urgency

- `standard` — normal notifications (default)
- `time_sensitive` — iOS Time Sensitive delivery (requires user permission)

## Idempotency

When you set `idempotency_key`, retries with the same key return the existing event (`duplicate: true`, HTTP 200) without billing again.

```ruby
result = client.send_event(
  channel: 'deploys',
  title: 'Production deploy complete',
  idempotency_key: 'deploy-prod-42'
)

puts result.duplicate ? 'duplicate' : 'new'
```

## Error handling

```ruby
begin
  client.send_event(channel: 'general', title: 'Hello')
rescue Trigv::ValidationError => e
  puts e.errors
rescue Trigv::NotFoundError
  puts 'Channel not found'
rescue Trigv::RateLimitError => e
  puts e.retryable ? 'Retry later' : 'Monthly limit reached'
end
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | `TRIGV_API_KEY` env | Workspace API key |
| `base_url` | `https://api.trigv.com/api` | API base URL |
| `timeout` | `30` | Request timeout (seconds) |
| `max_retries` | `2` | Retries for retryable errors |

### Verify connection

```ruby
connection = client.verify_connection
puts connection.workspace.name
```

## Examples

See the [`examples/`](./examples/) directory:

- Basic event
- Success event
- Warning event
- Full event with all optional fields
- Idempotency example
- Deploy completed (canonical example)
- Cron job failed
- WooCommerce order notification
- AI agent task completed

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Testing

```bash
bundle exec rspec
```

Tests use WebMock — no live API key required.

## Contributing

Contributions welcome. Please open an issue before large changes.

## Licence

MIT
