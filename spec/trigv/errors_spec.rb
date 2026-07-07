# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trigv::Errors do
  describe '.monthly_limit_message?' do
    it 'detects monthly cap messages' do
      expect(described_class.monthly_limit_message?('Monthly event limit reached for this workspace.')).to be(true)
      expect(described_class.monthly_limit_message?('Too many requests for this API key.')).to be(false)
    end
  end
end

RSpec.describe Trigv::RateLimitError do
  it 'defaults to retryable' do
    error = described_class.new('Too many requests')
    expect(error.retryable).to be(true)
    expect(error.status_code).to eq(429)
  end
end
