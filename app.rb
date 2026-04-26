# frozen_string_literal: true

require 'json'
require 'telegram/bot'

require 'dotenv'
Dotenv.load

Dir['./initializers/*.rb'].sort.each { |file| require file }
Dir['./app/*/*.rb'].sort.each { |file| require file }
Dir['./app/*/*/*.rb'].sort.each { |file| require file }

class App < Sinatra::Base
  set :host_authorization, { permitted_hosts: [] }

  before do
    I18n.locale = :en
    request.body.rewind if request.body.respond_to?(:rewind)
    @raw_body = request.body.read
    @json = JSON.parse(@raw_body, symbolize_names: true) rescue nil if request.content_type =~ /json/
  end

  def t(*args)
    I18n.t(*args)
  end

  get '/' do
    bot = Telegram::Bot::Api.new(TOKEN)
    puts bot.set_webhook(url: HOOK_URL)

    content_type :json, charset: 'utf-8'
    { webhook: true }.to_json
  end

  post '/' do
    return nil unless @json

    BotService.new(@json)
    status 200
  end
end

if __FILE__ == $0
  bot = Telegram::Bot::Api.new(TOKEN)
  BotService.new({ inline: true })
end
