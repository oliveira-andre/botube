# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'rake'

Dir['./initializers/*.rb'].sort.each { |file| require file }

Bundler.require(:default, settings.env)

Rake::TaskManager.record_task_metadata = true

require './app'

run App
