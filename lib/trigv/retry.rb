# frozen_string_literal: true

require 'time'

module Trigv
  module Retry
    module_function

    def parse_retry_after(value, now = Time.now)
      return nil if value.nil? || value.strip.empty?

      trimmed = value.strip

      if trimmed.match?(/\A\d+\z/)
        seconds = trimmed.to_i
        return nil if seconds.negative?

        return seconds.to_f
      end

      retry_at = Time.httpdate(trimmed)
      wait = retry_at - now
      wait.negative? ? nil : wait
    rescue ArgumentError
      nil
    end
  end
end
