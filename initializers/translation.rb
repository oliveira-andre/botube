# frozen_string_literal: true

require 'rubygems'
require 'rack_locale'
require 'sinatra'
require 'i18n'
require 'i18n/backend/fallbacks'

use RubySouth::Rack::Locale

configure do
  I18n.backend = I18n::Backend::Simple.new
  I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
  I18n.enforce_available_locales = false
  I18n.backend.load_translations
end
