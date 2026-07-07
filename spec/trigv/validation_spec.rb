# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trigv::Validation do
  describe '.validate_send_event_params' do
    it 'requires channel and title' do
      expect { described_class.validate_send_event_params(title: 'x') }
        .to raise_error(Trigv::ValidationError, /channel is required/)

      expect { described_class.validate_send_event_params(channel: 'general') }
        .to raise_error(Trigv::ValidationError, /title is required/)
    end

    it 'trims whitespace' do
      body = described_class.validate_send_event_params(channel: '  general  ', title: ' Hello ')
      expect(body).to eq('channel' => 'general', 'title' => 'Hello')
    end

    it 'accepts each valid level' do
      Trigv::LEVELS.each do |level|
        body = described_class.validate_send_event_params(channel: 'general', title: 'x', level: level)
        expect(body['level']).to eq(level)
      end
    end

    it 'rejects invalid delivery_urgency' do
      expect do
        described_class.validate_send_event_params(channel: 'general', title: 'x', delivery_urgency: 'urgent')
      end.to raise_error(Trigv::ValidationError, /delivery_urgency/)
    end

    it 'rejects prohibited icon field' do
      expect do
        described_class.validate_send_event_params(channel: 'general', title: 'x', icon: 'bell')
      end.to raise_error(Trigv::ValidationError, /icon/)
    end

    it 'rejects unknown fields' do
      expect do
        described_class.validate_send_event_params(channel: 'general', title: 'x', sound: 'ping')
      end.to raise_error(Trigv::ValidationError, /Unknown field/)
    end

    it 'enforces max length on title' do
      expect do
        described_class.validate_send_event_params(channel: 'general', title: 'x' * 256)
      end.to raise_error(Trigv::ValidationError, /title must be at most/)
    end
  end
end
