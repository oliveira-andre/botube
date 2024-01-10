# frozen_string_literal: true

Dir['./app/services/*.rb'].sort.each { |file| require file }

require 'telegram/bot'
require 'rest-client'
require 'pathname'
require 'ytdl'
require 'open-uri'

class BotService < ApplicationService
  def initialize(data)
    YoutubeDL::Command.config.executable = 'youtube-dl'
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
    @bot.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
  end

  def process_link
    message = t('processing')
    message_result = @bot.send_message(chat_id: @message.chat.id, text: message, parse_mode: 'HTML')
    message_id = message_result['result']['message_id']

    if @message.text.include?('youtu')
      message = t('choose_format')
      kb = [[
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Audio', callback_data: "audio_#{message_id}_#{@message.text}", remove_keyboard: true),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Video', callback_data: "video_#{message_id}_#{@message.text}", remove_keyboard: true)
      ]]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, reply_markup: markup, parse_mode: 'HTML')
    else
      message = t('not_found')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
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
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end.on_error do |state:, line:|
      puts "Error: #{state.error}"
      message = t('error')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end.on_complete do |state:, line:|
      puts "Complete: #{state.destination}"

      message = t('downloaded')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')

      # encoded_destination = "#{state.destination.to_s.split('.').first}.opus"
      encoded_destination = "#{state.destination.to_s.split('.').first}.mp3"
      @bot.sendAudio(
        chat_id: @message.chat.id,
        audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
      @finished = true
    end.call

    puts 'Audio downloaded!'

    return if @finished

    puts "Complete: #{state.destination}"

    message = t('downloaded')
    @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')

    # encoded_destination = "#{state.destination.to_s.split('.').first}.opus"
    encoded_destination = "#{state.destination.to_s.gsub('.webm', '.mp3')}"
    @bot.sendAudio(
      chat_id: @message.chat.id,
      audio: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
    )
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
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end.on_error do |state:, line:|
      puts "Error: #{state.error}"
      message = t('error')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')
    end.on_complete do |state:, line:|
      puts "Complete: #{state.destination}"

      message = t('downloaded')
      @bot.edit_message_text(chat_id: @message.chat.id, message_id: message_id, text: message, parse_mode: 'HTML')

      encoded_destination = state.destination.to_s
      @bot.sendVideo(
        chat_id: @message.chat.id,
        video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
      )
      @finished = true
    end.call

    puts 'Video downloaded!'
    return if @finished

    encoded_destination = state.destination.to_s
    @bot.sendVideo(
      chat_id: @message.chat.id,
      video: Faraday::UploadIO.new(encoded_destination, 'multipart/form-data')
    )
    @finished = true
  rescue StandardError
    puts 'Video already downloaded'
  end
end
