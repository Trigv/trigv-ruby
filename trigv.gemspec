# frozen_string_literal: true

require_relative 'lib/trigv/version'

Gem::Specification.new do |spec|
  spec.name = 'trigv'
  spec.version = Trigv::VERSION
  spec.authors = ['Trigv']
  spec.email = ['hello@trigv.com']

  spec.summary = 'Official Trigv SDK for Ruby — send notification events to your workspace'
  spec.description = 'Thin HTTP client for the Trigv workspace ingest API (events and connection verification).'
  spec.homepage = 'https://trigv.com'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'documentation_uri' => 'https://trigv.com/docs/sdks/ruby/',
    'source_code_uri' => 'https://github.com/Trigv/trigv-ruby',
    'bug_tracker_uri' => 'https://github.com/Trigv/trigv-ruby/issues',
    'changelog_uri' => 'https://github.com/Trigv/trigv-ruby/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb', 'README.md', 'LICENSE', 'CHANGELOG.md']

  spec.require_paths = ['lib']
end
