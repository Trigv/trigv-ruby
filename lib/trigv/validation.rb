# frozen_string_literal: true

module Trigv
  module Validation
    DEFAULT_BASE_URL = 'https://api.trigv.com/api'
    DEFAULT_TIMEOUT = 30
    MAX_RETRIES = 2

    LEVELS = %w[info success warning error].freeze
    DELIVERY_URGENCIES = %w[standard time_sensitive].freeze

    FIELD_MAX_LENGTHS = {
      channel: 120,
      title: 255,
      description: 1000,
      image_url: 2048,
      event_type: 120,
      idempotency_key: 190
    }.freeze

    PROHIBITED_FIELDS = %w[api_key icon].freeze

    ALLOWED_EVENT_KEYS = %i[
      channel title description image_url level delivery_urgency event_type idempotency_key
    ].freeze

    module_function

    def validate_send_event_params(params)
      params = params.transform_keys(&:to_sym)

      unknown = params.keys - ALLOWED_EVENT_KEYS
      unless unknown.empty?
        field = unknown.first.to_s
        raise ValidationError.new("Unknown field \"#{field}\"", { field => ["Unknown field \"#{field}\""] })
      end

      PROHIBITED_FIELDS.each do |prohibited|
        next unless params.key?(prohibited.to_sym)

        raise ValidationError.new(
          "Field \"#{prohibited}\" is not allowed",
          { prohibited => ["The #{prohibited} field is prohibited"] }
        )
      end

      channel = trim(params[:channel])
      title = trim(params[:title])

      raise ValidationError.new('channel is required', { channel: ['channel is required'] }) if channel.nil?
      raise ValidationError.new('title is required', { title: ['title is required'] }) if title.nil?

      assert_max_length('channel', channel, FIELD_MAX_LENGTHS[:channel])
      assert_max_length('title', title, FIELD_MAX_LENGTHS[:title])

      body = { 'channel' => channel, 'title' => title }

      description = trim(params[:description])
      if description
        assert_max_length('description', description, FIELD_MAX_LENGTHS[:description])
        body['description'] = description
      end

      image_url = trim(params[:image_url])
      if image_url
        assert_max_length('image_url', image_url, FIELD_MAX_LENGTHS[:image_url])
        body['image_url'] = image_url
      end

      level = trim(params[:level])
      if level
        assert_enum('level', level, LEVELS)
        body['level'] = level
      end

      delivery_urgency = trim(params[:delivery_urgency])
      if delivery_urgency
        assert_enum('delivery_urgency', delivery_urgency, DELIVERY_URGENCIES)
        body['delivery_urgency'] = delivery_urgency
      end

      event_type = trim(params[:event_type])
      if event_type
        assert_max_length('event_type', event_type, FIELD_MAX_LENGTHS[:event_type])
        body['event_type'] = event_type
      end

      idempotency_key = trim(params[:idempotency_key])
      if idempotency_key
        assert_max_length('idempotency_key', idempotency_key, FIELD_MAX_LENGTHS[:idempotency_key])
        body['idempotency_key'] = idempotency_key
      end

      body
    end

    def trim(value)
      return nil if value.nil?

      trimmed = value.to_s.strip
      trimmed.empty? ? nil : trimmed
    end

    def assert_max_length(field, value, max)
      return if value.length <= max

      message = "#{field} must be at most #{max} characters"
      raise ValidationError.new(message, { field => [message] })
    end

    def assert_enum(field, value, allowed)
      return if allowed.include?(value)

      message = "#{field} must be one of: #{allowed.join(', ')}"
      raise ValidationError.new(message, { field => [message] })
    end
  end
end
