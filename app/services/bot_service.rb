# frozen_string_literal: true

Dir['./app/services/*.rb'].sort.each { |file| require file }

require 'telegram/bot'
require 'rest-client'
require 'pathname'
require 'ytdl'
require 'open-uri'
require 'byebug'

class BotService < ApplicationService
  def initialize(data)
    YoutubeDL::Command.config.executable = 'youtube-dl'
    @data = data
    unless @data[:inline]
      @bot = Telegram::Bot::Api.new(TOKEN)
      @updater = Telegram::Bot::Types::Update.new(data)
      @message = @updater&.message
      @callback_query = @updater.callback_query
    end

    execute
  end

  def execute
    if @data[:inline]
      Telegram::Bot::Client.run(TOKEN) do |bot|
        @bot = bot
        @bot.listen do |message|
          case message
          when Telegram::Bot::Types::CallbackQuery
            @callback_query = message
            callback_queries
          when Telegram::Bot::Types::Message
            @message = message
            messages_queries
          end
        end
      end
    else
      messages_queries if @message
      callback_queries if @callback_query
    end
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
    process_audio if @callback_query.data.start_with?('audio')
    process_video if @callback_query.data.start_with?('video')
  end

  def messages_queries
    return unless @message.text

    @telegram_id = if @message.chat.type == 'private'
                     @message.chat.id
                   else
                     0 # TODO: fix to when this bot is on group
                   end
    start_message if @message.text.start_with?('/start')
    process_link if @message.text.start_with?('http')
  end

  # message queries

  def start_message
    message = t('welcome')
    if @data[:inline]
      @bot.api.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
    else
      @bot.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
    end
  end

  def process_link
    message = t('processing')
    message_result = if @data[:inline]
                       @bot.api.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
                     else
                       @bot.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
                     end
    message_id = message_result['result']['message_id']

    if @message.text.include?('youtu')
      message = t('choose_format')
      kb = [[
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Audio', callback_data: "audio_#{message_id}_#{@message.text}", remove_keyboard: true),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Video', callback_data: "video_#{message_id}_#{@message.text}", remove_keyboard: true)
      ]]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, reply_markup: markup, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, reply_markup: markup, parse_mode: 'HTML')
      end
    else
      message = t('not_found')
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end
    end
  end

  # callback queries

  def process_audio
    if @finished
      @finished = false
      raise StandardError, 'Video already downloaded'
    end

    link = @callback_query.data.split('_').last
    message_id = @callback_query.data.split('_')[1]
    puts 'Downloading audio...'

    temp_destination = File.expand_path("./tmp")
    state = YoutubeDL.download(link, output: "#{temp_destination}/%(title)s.%(ext)s", extract_audio: true, audio_format: 'mp3')
             .on_progress do |state:, line:|
      puts "Progress: #{state.progress}%"
      next if @last_progress == state.progress

      @last_progress = state.progress
      message = "#{t('downloading')} #{state.progress}%"
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end
    end.on_error do |state:, line:|
      puts "Error: #{state.error}"
      message = t('error')
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end
    end.on_complete do |state:, line:|
      puts "Complete: #{state.destination}"

      message = t('downloaded')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')

      # encoded_destination = "#{state.destination.to_s.split('.').first}.opus"
      encoded_destination = "#{state.destination.to_s.gsub('.webm', '.mp3').gusb('.m4a', '.mp3')}"
      if @data[:inline]
        @bot.api.sendAudio(
          chat_id: @message.chat.id,
          audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
        )
      else
        @bot.sendAudio(
          chat_id: @message.chat.id,
          audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
        )
      end
      @finished = true
    end.call

    puts 'Audio downloaded!'

    return if @finished

    puts "Complete: #{state.destination}"

    message = t('downloaded')
    if @data[:inline]
      @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    else
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end

    # encoded_destination = "#{state.destination.to_s.split('.').first}.opus"
    encoded_destination = "#{state.destination.to_s.gsub('.webm', '.mp3').gsub('.m4a', '.mp3')}"
    if @data[:inline]
      @bot.api.sendAudio(
        chat_id: @message.chat.id,
        audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
    else
      @bot.sendAudio(
        chat_id: @message.chat.id,
        audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
    end
    @finished = true
  rescue StandardError
    puts 'Audio already downloaded'
  end

  def process_video
    if @finished
      @finished = false
      raise StandardError, 'Video already downloaded'
    end

    link = @callback_query.data.split('_').last
    message_id = @callback_query.data.split('_')[1]
    puts 'Downloading Video...'

    temp_destination = File.expand_path("./tmp")
    state = YoutubeDL.download(link, output: "#{temp_destination}/%(title)s.%(ext)s", format: 'mp4')
                     .on_progress do |state:, line:|
      puts "Progress: #{state.progress}%"
      next if @last_progress == state.progress

      @last_progress = state.progress
      message = "#{t('downloading')} #{state.progress}%"
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end
    end.on_error do |state:, line:|
      puts "Error: #{state.error}"
      message = t('error')
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end
    end.on_complete do |state:, line:|
      puts "Complete: #{state.destination}"

      message = t('downloaded')
      if @data[:inline]
        @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      else
        @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
      end

      encoded_destination = state.destination.to_s
      if @data[:inline]
        @bot.api.sendVideo(
          chat_id: @message.chat.id,
          video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
        )
      else
        @bot.sendVideo(
          chat_id: @message.chat.id,
          video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
        )
      end
      @finished = true
    end.call

    puts 'Video downloaded!'
    return if @finished

    message = t('downloaded')
    if @data[:inline]
      @bot.api.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    else
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end

    encoded_destination = state.destination.to_s
    if @data[:inline]
      @bot.api.sendVideo(
        chat_id: @message.chat.id,
        video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
    else
      @bot.sendVideo(
        chat_id: @message.chat.id,
        video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
    end
    @finished = true
  rescue StandardError => e
    puts e
    puts 'Video already downloaded'
  end
end
