# frozen_string_literal: true

Dir['./app/services/*.rb'].sort.each { |file| require file }

require 'telegram/bot'
require 'rest-client'

class BotService < ApplicationService
  def initialize(data)
    @bot = Telegram::Bot::Api.new(TOKEN)
    @updater = Telegram::Bot::Types::Update.new(data)
    @message = @updater&.message
    @callback_query = @updater.callback_query
    execute
  end

  def execute
    messages_queries if @message
    callback_queries if @callback_query
  rescue StandardError => e
    puts e
    true
  end

  private

  def callback_queries
    @message = @callback_query.message

    @telegram_id = if @message.chat.type == 'private'
                     @message.chat.id
                   else
                     0 # TODO: fix to when this bot is on group
                   end
    another_start_message if @callback_query.data.start_with?('start')
  end

  def messages_queries
    return unless @message.text

    @telegram_id = if @message.chat.type == 'private'
                     @message.chat.id
                   else
                     0 # TODO: fix to when this bot is on group
                   end
    start_message if @message.text.start_with?('/start')
  end

  # message queries

  def start_message
    message = t('welcome')
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Start Button', callback_data: 'start')
    ]
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    @bot.send_message(chat_id: @message.chat.id, text: message, reply_markup: markup)
  end

  # callback queries

  def another_start_message
    message = t('another_welcome')
    @bot.send_message(chat_id: @message.chat.id, text: message)
  end
end
