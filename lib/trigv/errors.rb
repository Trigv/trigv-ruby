# frozen_string_literal: true

module Trigv
  class Error < StandardError
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
    attr_reader :status_code, :retryable, :retry_after_seconds

    def initialize(message, retryable: true, retry_after_seconds: nil)
      super(message)
      @status_code = 429
      @retryable = retryable
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

  module Errors
    module_function

    def monthly_limit_message?(message)
      message.include?('Monthly event limit')
    end
  end
end
