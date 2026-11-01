# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

require_relative 'retry'

module Trigv
  Event = Struct.new(
    :public_id, :event_uuid, :status, :level, :event_type, :target_device_count, :received_at,
    keyword_init: true
  )

  SendEventResult = Struct.new(:event, :duplicate, keyword_init: true)

  ConnectionWorkspace = Struct.new(:public_id, :name, keyword_init: true)
  ConnectionApiKey = Struct.new(:public_id, :name, :prefix, keyword_init: true)
  ConnectionResult = Struct.new(:workspace, :api_key, keyword_init: true)

  class Client
    attr_reader :api_key, :base_url, :timeout, :max_retries

    def initialize(
      api_key: nil,
      base_url: Validation::DEFAULT_BASE_URL,
      timeout: Validation::DEFAULT_TIMEOUT,
      max_retries: Validation::MAX_RETRIES
    )
      api_key ||= ENV.fetch('TRIGV_API_KEY', nil)
      api_key = api_key&.strip
      raise ValidationError, 'api_key is required (or set TRIGV_API_KEY)' if api_key.nil? || api_key.empty?
      raise ValidationError, 'max_retries must be zero or greater' if max_retries.negative?
      raise ValidationError, 'timeout must be greater than zero' if timeout <= 0

      @api_key = api_key
      @base_url = base_url.to_s.chomp('/')
      @timeout = timeout
      @max_retries = max_retries
    end

    def user_agent
      "trigv-ruby/#{VERSION}"
    end

    def send_event(**params)
      body = Validation.validate_send_event_params(params)
      has_idempotency = body.key?('idempotency_key')

      request_with_retry(:post, '/v1/events', body, allow_retry: has_idempotency) do |status, parsed, headers|
        if [200, 202].include?(status) && parsed&.dig('event')
          event = parse_event(parsed['event'])
          SendEventResult.new(event: event, duplicate: status == 200)
        else
          error_from_response(status, parsed, headers)
        end
      end
    end

    def verify_connection
      request_with_retry(:get, '/v1/connection', nil, allow_retry: true) do |status, parsed, headers|
        if status == 200 && parsed&.dig('workspace') && parsed['api_key']
          parse_connection_result(parsed)
        else
          error_from_response(status, parsed, headers)
        end
      end
    end

    private

    def request_with_retry(method, path, body, allow_retry:)
      last_error = nil

      (0..max_retries).each do |attempt|
        status, parsed, headers = request_once(method, path, body)
        return yield(status, parsed, headers)
      rescue StandardError => e
        last_error = e
        raise e unless allow_retry && attempt < max_retries
        raise e unless retryable_error?(e)

        wait = retry_wait_seconds(e, attempt)
        sleep([wait, timeout].min)
      end

      raise last_error
    end

    def retry_wait_seconds(error, attempt)
      return error.retry_after_seconds if error.respond_to?(:retry_after_seconds) && error.retry_after_seconds

      (0.5 * (2**attempt)) + (rand * 0.25)
    end

    def retryable_error?(error)
      case error
      when ValidationError, AuthenticationError, AuthorizationError, NotFoundError
        false
      when RateLimitError, ConflictError, ServiceUnavailableError
        true
      when ApiError
        retryable_status?(error.status_code)
      when NetworkError, TimeoutError
        true
      else
        false
      end
    end

    def retryable_status?(status)
      [502, 504].include?(status)
    end

    def request_once(method, path, body)
      uri = build_uri(path)
      http = build_http(uri)
      request = build_request(method, uri, body)
      response = http.request(request)
      parsed = parse_json(response.body)
      response_headers = response.each_header.to_h.transform_keys(&:downcase)

      [response.code.to_i, parsed, response_headers]
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      raise TimeoutError
    rescue Error
      raise
    rescue StandardError => e
      raise NetworkError.new(e.message, e)
    end

    def build_uri(path)
      URI("#{@base_url}#{path}")
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = timeout
      http.read_timeout = timeout
      http
    end

    def build_request(method, uri, body)
      request =
        case method
        when :get then Net::HTTP::Get.new(uri)
        when :post then Net::HTTP::Post.new(uri)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end

      request['Accept'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
      request['User-Agent'] = user_agent

      if body
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body)
      end

      request
    end

    def parse_json(text)
      return nil if text.nil? || text.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    def parse_event(data)
      Event.new(
        public_id: data['public_id'],
        event_uuid: data['event_uuid'],
        status: data['status'],
        level: data['level'],
        event_type: data['event_type'],
        target_device_count: data['target_device_count'],
        received_at: data['received_at']
      )
    end

    def parse_connection_result(parsed)
      workspace_data = parsed['workspace']
      api_key_data = parsed['api_key']

      unless workspace_data.is_a?(Hash) && api_key_data.is_a?(Hash)
        raise ValidationError.new('Invalid connection response payload', {})
      end

      required_workspace = %w[public_id name]
      required_api_key = %w[public_id name prefix]
      missing_workspace = required_workspace.reject { |key| workspace_data[key].is_a?(String) && !workspace_data[key].empty? }
      missing_api_key = required_api_key.reject { |key| api_key_data[key].is_a?(String) && !api_key_data[key].empty? }

      unless missing_workspace.empty? && missing_api_key.empty?
        raise ValidationError.new('Invalid connection response payload', {})
      end

      ConnectionResult.new(
        workspace: ConnectionWorkspace.new(**symbolize_keys(workspace_data)),
        api_key: ConnectionApiKey.new(**symbolize_keys(api_key_data))
      )
    rescue ArgumentError, KeyError, TypeError
      raise ValidationError.new('Invalid connection response payload', {})
    end

    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end

    def error_from_response(status, body, headers = {})
      message = body&.fetch('message', nil) || "Trigv API returned HTTP #{status}"
      retry_after = Retry.parse_retry_after(headers['retry-after'])

      error =
        case status
        when 401 then AuthenticationError.new(message)
        when 403 then AuthorizationError.new(message)
        when 404 then NotFoundError.new(message)
        when 409 then ConflictError.new(message, retry_after_seconds: retry_after)
        when 422 then ValidationError.new(message, body&.fetch('errors', {}) || {})
        when 429 then RateLimitError.new(message, retry_after_seconds: retry_after)
        when 503 then ServiceUnavailableError.new(message, retry_after_seconds: retry_after)
        else ApiError.new(message, status, body)
        end

      error.request_id = headers['x-request-id']
      raise error
    end
  end
end
