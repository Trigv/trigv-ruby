# trigv

[Docs](https://trigv.com/docs/sdks/ruby/) | [API reference](https://trigv.com/docs/api/) | [Free tools](https://trigv.com/tools/) | [Get an API key](https://app.trigv.com/register)

Official Trigv SDK for Ruby. Send notification events from scripts, servers, and CI pipelines.

## What Trigv is

Trigv delivers developer notifications to your team's devices. Your backend sends lightweight JSON events; Trigv queues push delivery. Notification title and body are not stored on Trigv servers — metadata only.

## Installation

Add to your Gemfile:

```ruby
gem 'trigv', '~> 1.1'
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
puts result.request_id # X-Request-ID header, or nil if missing
```

## Event options

| Field | Required | Description |
|-------|:--------:|-------------|
| `channel` | Yes | Channel slug (e.g. `general`, max 120 characters) |
| `title` | Yes | Notification title (max 255 characters) |
| `description` | No | Body text (max 1000 characters) |
| `image_url` | No | Image URL (max 2048 characters; not stored server-side) |
| `url` | No | Destination URL for the notification (max 2048 characters; not stored server-side) |
| `level` | No | `info`, `success`, `warning`, `error` (default: `info`) |
| `delivery_urgency` | No | `standard` or `time_sensitive` (default: `standard`) |
| `event_type` | No | Free-form label (e.g. `deploy.completed`, max 120 characters) |
| `idempotency_key` | No | Dedup key per workspace (max 190 characters) |

## Levels

- `info` — general information (default)
- `success` — completed successfully
- `warning` — attention needed
- `error` — failure or alert

## Delivery urgency

- `standard` — normal notifications (default)
- `time_sensitive` — iOS Time Sensitive delivery (requires user permission)

## Idempotency

When you set `idempotency_key`, retries with the same key return the existing event (`duplicate: true`, HTTP 200, message `already stored`) without billing again. A 409 or 503 is retried with the same key, honouring `Retry-After`.

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
rescue Trigv::RateLimitError, Trigv::ConflictError, Trigv::ServiceUnavailableError => e
  puts "Retry in #{e.retry_after_seconds}s (request id #{e.request_id})"
end
```

| Error | HTTP | Retried (with `idempotency_key`) |
|-------|------|:---:|
| `Trigv::AuthenticationError` | 401 | No |
| `Trigv::AuthorizationError` | 403 | No |
| `Trigv::NotFoundError` | 404 | No |
| `Trigv::ConflictError` | 409, same key being delivered | Yes |
| `Trigv::ValidationError` | 422 | No |
| `Trigv::RateLimitError` | 429, 60 requests per minute per workspace | Yes |
| `Trigv::ServiceUnavailableError` | 503, push unavailable | Yes |

Retries wait for `Retry-After`. If `Retry-After` is longer than the client `timeout`, the error is raised at once. 502 and 504 responses, network errors and timeouts are also retried (with an `idempotency_key`), and so is `verify_connection`. Every error has `request_id`, the `X-Request-ID` header. Successful results have `request_id` too (`nil` if missing). Quote it to support.

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | `TRIGV_API_KEY` env | Workspace API key |
| `base_url` | `https://api.trigv.com` | API base URL. A URL ending in `/api` still works |
| `timeout` | `30` | Request timeout (seconds) |
| `max_retries` | `2` | Retries for retryable errors |

### Verify connection

```ruby
connection = client.verify_connection
puts connection.workspace.name
puts connection.request_id # X-Request-ID header, or nil if missing
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
