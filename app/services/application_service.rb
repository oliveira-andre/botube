# frozen_string_literal: true

class ApplicationService
  def initialize(bot, message, telegram_id)
    @bot = bot
    @message = message
    @telegram_id = telegram_id
  end

  def t(*args)
    I18n.t(*args)
  end
end
