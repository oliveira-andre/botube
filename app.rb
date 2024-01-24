# frozen_string_literal: true

require 'json'
require 'telegram/bot'

require 'dotenv'
Dotenv.load

Dir['./initializers/*.rb'].sort.each { |file| require file }
Dir['./app/*/*.rb'].sort.each { |file| require file }
Dir['./app/*/*/*.rb'].sort.each { |file| require file }

class App < Sinatra::Base
  before do
    I18n.locale = :en
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
    request.body.rewind
    data = JSON.parse(request.body.read)
    BotService.new(data)
    status 200
  end
end

if __FILE__ == $0
  bot = Telegram::Bot::Api.new(TOKEN)
  BotService.new({ inline: true })
end
