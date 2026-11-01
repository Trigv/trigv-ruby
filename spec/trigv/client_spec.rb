# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trigv::Client do
  let(:api_key) { 'trgv_testkey1_abcdefghijklmnopqrstuvwxyz123456' }
  let(:base_url) { 'https://api.trigv.com' }

  let(:sample_event) do
    {
      'public_id' => '01JXXXXXXXXXXXXXXXXXXXXXXX',
      'event_uuid' => '550e8400-e29b-41d4-a716-446655440000',
      'status' => 'sent',
      'level' => 'info',
      'event_type' => nil,
      'target_device_count' => 1,
      'received_at' => '2026-06-16T12:00:00+00:00'
    }
  end

  let(:client) { described_class.new(api_key: api_key, max_retries: 0) }

  let(:full_event_params) do
    {
      channel: 'deploys',
      title: 'Production deploy complete',
      description: 'Build #42 succeeded in 38s (commit abc1234)',
      level: 'success',
      delivery_urgency: 'standard',
      event_type: 'deploy.completed',
      idempotency_key: 'deploy-prod-42',
      url: 'https://example.com/deployments/42'
    }
  end

  it 'requires an API key' do
    expect { described_class.new(api_key: '') }.to raise_error(Trigv::ValidationError)
  end

  it 'sends a minimum valid event' do
    stub = stub_request(:post, "#{base_url}/v1/events")
           .with(
             headers: {
               'Accept' => 'application/json',
               'Authorization' => "Bearer #{api_key}",
               'Content-Type' => 'application/json',
               'User-Agent' => %r{^trigv-ruby/}
             },
             body: { channel: 'general', title: 'Hello' }.to_json
           )
           .to_return(status: 202, body: { event: sample_event }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = client.send_event(channel: 'general', title: 'Hello')

    expect(stub).to have_been_requested
    expect(result.duplicate).to be(false)
    expect(result.event.public_id).to eq('01JXXXXXXXXXXXXXXXXXXXXXXX')
  end

  it 'sends all optional fields' do
    captured = nil
    stub_request(:post, "#{base_url}/v1/events")
      .to_return do |request|
        captured = JSON.parse(request.body)
        { status: 202, body: { event: sample_event.merge('level' => 'success') }.to_json,
          headers: { 'Content-Type' => 'application/json' } }
      end

    client.send_event(**full_event_params)
    expect(captured).to include(full_event_params.transform_keys(&:to_s))
  end

  it 'rejects invalid level client-side' do
    expect do
      client.send_event(channel: 'general', title: 'x', level: 'meta')
    end.to raise_error(Trigv::ValidationError)
  end

  it 'handles duplicate idempotency' do
    stub_request(:post, "#{base_url}/v1/events")
      .to_return(status: 200, body: { event: sample_event }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = client.send_event(channel: 'general', title: 'x', idempotency_key: 'retry-123')
    expect(result.duplicate).to be(true)
  end

  it 'maps 401 to AuthenticationError' do
    stub_request(:post, "#{base_url}/v1/events")
      .to_return(status: 401, body: { message: 'Unauthorized' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect do
      client.send_event(channel: 'general', title: 'x')
    end.to raise_error(Trigv::AuthenticationError)
  end

  it 'maps 404 to NotFoundError' do
    stub_request(:post, "#{base_url}/v1/events")
      .to_return(
        status: 404,
        body: { message: 'Channel not found.' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect do
      client.send_event(channel: 'missing', title: 'x')
    end.to raise_error(Trigv::NotFoundError)
  end

  it 'retries burst rate limit when idempotency key set' do
    client = described_class.new(api_key: api_key, max_retries: 2)
    calls = 0

    stub_request(:post, "#{base_url}/v1/events")
      .to_return do
        calls += 1
        if calls == 1
          { status: 429, body: { message: 'Too many requests for this API key.' }.to_json,
            headers: { 'Content-Type' => 'application/json' } }
        else
          { status: 202, body: { event: sample_event }.to_json,
            headers: { 'Content-Type' => 'application/json' } }
        end
      end

    allow(client).to receive(:sleep)

    result = client.send_event(channel: 'general', title: 'x', idempotency_key: 'k1')
    expect(calls).to eq(2)
    expect(result.event.public_id).to eq('01JXXXXXXXXXXXXXXXXXXXXXXX')
  end

  it 'verify_connection returns metadata' do
    stub_request(:get, "#{base_url}/v1/connection")
      .to_return(
        status: 200,
        body: {
          workspace: { public_id: 'ws_1', name: 'Test' },
          api_key: { public_id: 'key_1', name: 'Default', prefix: 'trgv_testkey1' }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = client.verify_connection
    expect(result.workspace.name).to eq('Test')
  end

  it 'does not expose API key in error messages' do
    stub_request(:post, "#{base_url}/v1/events")
      .to_return(status: 401, body: { message: 'Unauthorized' }.to_json, headers: { 'Content-Type' => 'application/json' })

    begin
      client.send_event(channel: 'general', title: 'x')
    rescue Trigv::AuthenticationError => e
      expect(e.message).not_to include(api_key)
    end
  end

  it 'sets User-Agent header' do
    stub = stub_request(:post, "#{base_url}/v1/events")
           .with(headers: { 'User-Agent' => %r{^trigv-ruby/} })
           .to_return(status: 202, body: { event: sample_event }.to_json, headers: { 'Content-Type' => 'application/json' })

    client.send_event(channel: 'general', title: 'x')
    expect(stub).to have_been_requested
  end

  it 'maps 422 to ValidationError with field errors' do
    stub_request(:post, "#{base_url}/v1/events")
      .to_return(
        status: 422,
        body: { message: 'Validation failed', errors: { channel: ['invalid'] } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect do
      client.send_event(channel: 'general', title: 'x')
    end.to raise_error(Trigv::ValidationError) { |error| expect(error.errors).to eq({ 'channel' => ['invalid'] }) }
  end

  it 'rejects prohibited api_key field client-side' do
    expect do
      client.send_event(channel: 'general', title: 'x', api_key: 'secret')
    end.to raise_error(Trigv::ValidationError)
  end

  it 'rejects negative max_retries' do
    expect do
      described_class.new(api_key: api_key, max_retries: -1)
    end.to raise_error(Trigv::ValidationError, /max_retries/)
  end

  it 'retries burst 429 with Retry-After header' do
    client = described_class.new(api_key: api_key, max_retries: 2)
    calls = 0
    stub_request(:post, "#{base_url}/v1/events")
      .to_return do
        calls += 1
        if calls == 1
          { status: 429, body: { message: 'Too many requests for this API key.' }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Retry-After' => '1' } }
        else
          { status: 202, body: { event: sample_event }.to_json,
            headers: { 'Content-Type' => 'application/json' } }
        end
      end

    allow(client).to receive(:sleep)

    client.send_event(channel: 'general', title: 'x', idempotency_key: 'k1')
    expect(calls).to eq(2)
  end

  it 'raises ValidationError for malformed connection payload' do
    stub_request(:get, "#{base_url}/v1/connection")
      .to_return(
        status: 200,
        body: { workspace: { public_id: 'ws_1' }, api_key: { public_id: 'key_1' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect { client.verify_connection }.to raise_error(Trigv::ValidationError, /Invalid connection/)
  end

  it 'omits url when not provided' do
    captured = nil
    stub_request(:post, "#{base_url}/v1/events")
      .to_return do |request|
        captured = JSON.parse(request.body)
        { status: 202, body: { event: sample_event }.to_json, headers: { 'Content-Type' => 'application/json' } }
      end

    client.send_event(channel: 'general', title: 'x')
    expect(captured).not_to have_key('url')
  end

  it 'rejects over-length url' do
    expect do
      client.send_event(channel: 'general', title: 'x', url: "https://example.com/#{'a' * 2040}")
    end.to raise_error(Trigv::ValidationError)
  end

  describe 'base URL' do
    it 'defaults to https://api.trigv.com/v1/events' do
      stub = stub_request(:post, 'https://api.trigv.com/v1/events')
             .to_return(status: 202, body: { event: sample_event }.to_json)

      described_class.new(api_key: api_key).send_event(channel: 'general', title: 'x')
      expect(stub).to have_been_requested
    end

    it 'keeps working with the old /api base URL' do
      stub = stub_request(:post, 'https://api.trigv.com/api/v1/events')
             .to_return(status: 202, body: { event: sample_event }.to_json)

      described_class.new(api_key: api_key, base_url: 'https://api.trigv.com/api/')
                     .send_event(channel: 'general', title: 'x')
      expect(stub).to have_been_requested
    end

    it 'builds /v1/connection from the default base URL' do
      stub = stub_request(:get, 'https://api.trigv.com/v1/connection')
             .to_return(status: 200, body: {
               workspace: { public_id: '01JXXXXXXXXXXXXXXXXXXXXXXX', name: 'Acme' },
               api_key: { public_id: '01JXXXXXXXXXXXXXXXXXXXXXXX', name: 'Prod', prefix: 'trgv_abcd1234' }
             }.to_json)

      described_class.new(api_key: api_key).verify_connection
      expect(stub).to have_been_requested
    end
  end

  describe 'error statuses' do
    def headers
      { 'Retry-After' => '7', 'X-Request-ID' => '01JREQXXXXXXXXXXXXXXXXXXXX' }
    end

    def stub_status(status, extra = {})
      stub_request(:post, "#{base_url}/v1/events")
        .to_return(status: status, body: { message: 'nope' }.to_json, headers: headers.merge(extra))
    end

    it 'maps 409 to ConflictError with Retry-After and request id' do
      stub_status(409)
      expect { client.send_event(channel: 'general', title: 'x') }.to raise_error(Trigv::ConflictError) do |e|
        expect(e.status_code).to eq(409)
        expect(e.retry_after_seconds).to eq(7)
        expect(e.request_id).to eq('01JREQXXXXXXXXXXXXXXXXXXXX')
      end
    end

    it 'maps 503 to ServiceUnavailableError with Retry-After' do
      stub_status(503)
      expect { client.send_event(channel: 'general', title: 'x') }.to raise_error(Trigv::ServiceUnavailableError) do |e|
        expect(e.retry_after_seconds).to eq(7)
      end
    end

    it 'maps 429 to RateLimitError with Retry-After and request id' do
      stub_status(429)
      expect { client.send_event(channel: 'general', title: 'x') }.to raise_error(Trigv::RateLimitError) do |e|
        expect(e.retry_after_seconds).to eq(7)
        expect(e.request_id).to eq('01JREQXXXXXXXXXXXXXXXXXXXX')
      end
    end

    it 'maps 422 (bad JSON body) to ValidationError and does not retry' do
      retrying = described_class.new(api_key: api_key, max_retries: 2)
      stub = stub_request(:post, "#{base_url}/v1/events")
             .to_return(status: 422, body: { message: 'The channel field is required.',
                                             errors: { 'channel' => ['The channel field is required.'] } }.to_json)

      expect { retrying.send_event(channel: 'general', title: 'x', idempotency_key: 'k') }
        .to raise_error(Trigv::ValidationError) { |e| expect(e.errors).to eq('channel' => ['The channel field is required.']) }
      expect(stub).to have_been_requested.once
    end

    it 'treats 200 already stored as duplicate' do
      stub_request(:post, "#{base_url}/v1/events")
        .to_return(status: 200, body: { event: sample_event, message: 'already stored' }.to_json)

      result = client.send_event(channel: 'general', title: 'x', idempotency_key: 'k')
      expect(result.duplicate).to be(true)
    end

    [409, 503].each do |status|
      it "retries #{status} with the same key after Retry-After" do
        retrying = described_class.new(api_key: api_key, max_retries: 2)
        bodies = []
        calls = 0
        stub_request(:post, "#{base_url}/v1/events").to_return do |request|
          calls += 1
          bodies << request.body
          if calls == 1
            { status: status, body: { message: 'retry' }.to_json, headers: { 'Retry-After' => '3' } }
          else
            { status: 202, body: { event: sample_event }.to_json }
          end
        end
        allow(retrying).to receive(:sleep)

        retrying.send_event(channel: 'general', title: 'x', idempotency_key: 'k1')
        expect(calls).to eq(2)
        expect(bodies.uniq.length).to eq(1)
        expect(retrying).to have_received(:sleep).with(3.0)
      end
    end

    [409, 429, 503].each do |status|
      it "raises #{status} at once when Retry-After is longer than the timeout" do
        retrying = described_class.new(api_key: api_key, max_retries: 2, timeout: 30)
        calls = 0
        stub_request(:post, "#{base_url}/v1/events").to_return do
          calls += 1
          { status: status, body: { message: 'slow down' }.to_json, headers: { 'Retry-After' => '3600' } }
        end
        allow(retrying).to receive(:sleep)

        expect { retrying.send_event(channel: 'general', title: 'x', idempotency_key: 'k1') }
          .to raise_error(Trigv::Error) { |error| expect(error.retry_after_seconds).to eq(3600) }
        expect(calls).to eq(1)
        expect(retrying).not_to have_received(:sleep)
      end
    end

    it 'does not retry 409 without an idempotency key' do
      retrying = described_class.new(api_key: api_key, max_retries: 2)
      stub = stub_status(409)
      expect { retrying.send_event(channel: 'general', title: 'x') }.to raise_error(Trigv::ConflictError)
      expect(stub).to have_been_requested.once
    end
  end
end
