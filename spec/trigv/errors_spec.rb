# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trigv::RateLimitError do
  it 'has status 429 and an optional retry_after_seconds' do
    error = described_class.new('Too many requests', retry_after_seconds: 5)
    expect(error.status_code).to eq(429)
    expect(error.retry_after_seconds).to eq(5)
  end
end

RSpec.describe Trigv::ConflictError do
  it 'has status 409' do
    expect(described_class.new('busy').status_code).to eq(409)
  end
end

RSpec.describe Trigv::ServiceUnavailableError do
  it 'has status 503' do
    expect(described_class.new('down').status_code).to eq(503)
  end
end

RSpec.describe Trigv::RateLimitError, '#retryable' do
  it 'keeps #retryable returning true and accepts retryable:' do
    expect(described_class.new('x').retryable).to be(true)
    error = described_class.new('x', retryable: false, retry_after_seconds: 5)
    expect(error.retryable).to be(true)
    expect(error.retry_after_seconds).to eq(5)
  end
end

RSpec.describe Trigv::Errors do
  it 'keeps monthly_limit_message? returning false' do
    expect(described_class.monthly_limit_message?('Monthly event limit reached')).to be(false)
  end
end
