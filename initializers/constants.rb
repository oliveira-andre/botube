# frozen_string_literal: true

require 'dotenv'
Dotenv.load

TOKEN = ENV['TELEGRAM_KEY_TOKEN']
HOOK_URL = ENV['HOOK_URL']

CONVERT_TO_LOCALE = { english: :en, portuguese: :pt }.freeze
