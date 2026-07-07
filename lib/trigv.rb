# frozen_string_literal: true

require 'trigv/version'
require 'trigv/errors'
require 'trigv/validation'
require 'trigv/client'

module Trigv
  DEFAULT_BASE_URL = Validation::DEFAULT_BASE_URL
  MAX_RETRIES = Validation::MAX_RETRIES
  LEVELS = Validation::LEVELS
  DELIVERY_URGENCIES = Validation::DELIVERY_URGENCIES
end
