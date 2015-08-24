#!/usr/bin/env ruby
require 'time'
require 'csv'

class TimeLogger
  AVAILABLE_PARAMS = [:start, :stop, :show, :start_pause, :stop_pause, :flush]
  DB_NAME = '/home/eugene0/code/time_log/db.json'
  PAUSE_NAME = '#PAUSE'
  FILE_KEYS = [:title, :start_time, :excluded_time]

  def initialize
    @params = {}
    @data = read_file
  end

  def run(params)
    parse_params(params)
    exec_params
    write_data
  end

  private

  def parse_params(params)
    params_stack = []
    params.each do |param|
      if argument?(param)
        params_stack << param[1..-1].to_sym
        add_param(params_stack.last, true)
      else
        add_param(params_stack.pop, param)
      end
    end
  end

  def read_file
    CSV.open(DB_NAME, encoding: 'UTF-8',
                      headers: true,
                      header_converters: :symbol).map do |line|
      { title: line[:title],
        start_time: Time.parse(line[:start_time]),
        excluded_time: line[:excluded_time].to_i }
    end
  end

  def write_data
    csv_data = CSV.generate do |csv|
      csv << FILE_KEYS
      @data.each do |row|
        csv << row.values
      end
    end

    File.open(DB_NAME, 'w:UTF-8') { |file| file.write(csv_data) }
  end

  def exec_params
    exec_show(true) if @params.empty?
    @params.each do |param, value|
      send("exec_#{param}", value)
    end
  end

  def exec_start(value)
    @data << { title: value, start_time: Time.now.to_s, excluded_time: 0 }
  end

  def exec_stop(value)
    record = @data.find { |r| r[:title] == value }
    if record
      puts show_time(record)
      @data.delete(record)
    else
      puts "You forget to start logging '#{value}'!"
      exit(2)
    end
  end

  def exec_show(_)
    @data.each do |record|
      puts " - Title: '#{record[:title]}' |" +
           " #{show_time(record)} |" +
           " Started: '#{record[:start_time]}'"
    end
  end

  def exec_start_pause(_)
    if record_exist?(PAUSE_NAME)
      puts 'Time already paused!'
    else
      puts 'Pause started.'
      exec_start(PAUSE_NAME)
    end
  end

  def exec_stop_pause(_)
    pause_record = exec_stop(PAUSE_NAME)
    @data.each do |record|
      record[:excluded_time] += (Time.now - pause_record[:start_time]).to_i
    end
  end

  def exec_flush(_)
    @data = []
  end

  def argument?(param)
    param[0] == '-'
  end

  def add_param(param, value)
    if AVAILABLE_PARAMS.include? param
      @params[param] = value
    else
      puts "Unknown param: '#{param}'"
      exit(1)
    end
  end

  def show_time(record)
    seconds = calculate_time(record)
    "Passed time is #{(seconds / 3600.0).round(2)} hours."
  end

  def calculate_time(record)
    Time.now - record[:start_time] - record[:excluded_time]
  end

  def record_exist?(value)
    @data.find { |record| record[:title] == value }
  end
end
