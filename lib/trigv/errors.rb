# frozen_string_literal: true

module Trigv
  class Error < StandardError
    # Value of the X-Request-ID response header, when the API answered.
    attr_accessor :request_id

    def initialize(message = nil)
      super
    end
  end

  class ValidationError < Error
    attr_reader :errors

    def initialize(message, errors = {})
      super(message)
      @errors = errors
    end
  end

  class AuthenticationError < Error
    attr_reader :status_code

    def initialize(message)
      super
      @status_code = 401
    end
  end

  class AuthorizationError < Error
    attr_reader :status_code

    def initialize(message)
      super
      @status_code = 403
    end
  end

  class NotFoundError < Error
    attr_reader :status_code

    def initialize(message)
      super
      @status_code = 404
    end
  end

  class RateLimitError < Error
    attr_reader :status_code, :retry_after_seconds

    def initialize(message, retry_after_seconds: nil)
      super(message)
      @status_code = 429
      @retry_after_seconds = retry_after_seconds
    end
  end

  # HTTP 409: another request is delivering the same idempotency_key.
  class ConflictError < Error
    attr_reader :status_code, :retry_after_seconds

    def initialize(message, retry_after_seconds: nil)
      super(message)
      @status_code = 409
      @retry_after_seconds = retry_after_seconds
    end
  end

  # HTTP 503: push delivery is unavailable. Retry with the same idempotency_key.
  class ServiceUnavailableError < Error
    attr_reader :status_code, :retry_after_seconds

    def initialize(message, retry_after_seconds: nil)
      super(message)
      @status_code = 503
      @retry_after_seconds = retry_after_seconds
    end
  end

  class ApiError < Error
    attr_reader :status_code, :body

    def initialize(message, status_code, body = nil)
      super(message)
      @status_code = status_code
      @body = body
    end
  end

  class NetworkError < Error
    attr_reader :cause

    def initialize(message, cause = nil)
      super
      @cause = cause
    end
  end

  class TimeoutError < Error
    def initialize(message = 'Request timed out')
      super
    end
  end
end
