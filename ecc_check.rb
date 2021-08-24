#!/usr/bin/env ruby
#encoding: utf-8
#frozen_string_literal: true

require 'json'
require 'logger'
require 'net/ssh'
require 'optparse'

#
# Parse Options
#

options = {
  delay: 60,
  host: nil,
  username: nil
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ecc_check.rb [options]'

  opts.on('-dDELAY', '--delay=DELAY', 'Time in seconds between connection attempts') do |d|
    options[:delay] = d.to_i
  end

  opts.on('-rHOST', '--remote=HOST', 'Remote host to use instead of localhost') do |h|
    options[:host] = h
  end

  opts.on('-uUSERNAME', '--username=USERNAME', 'Username for the remote host') do |u|
    options[:username] = u
  end
end.parse!

#
# Validate Options
#

if options[:delay] <= 0
  raise 'Delay must be greater than 0'
end

#
# Run & Report
#

class Runner

  def initialize(options)
    @options = options
    @logger = Logger.new(STDOUT)
  end

  def run
    loop do
      data = capture
      parse(data) unless data.nil?

      sleep @options[:delay]
    end
  end

  private

  def capture
    # Get the data
    data = nil

    if @options[:host].nil?
      data = `system_profiler -json SPMemoryDataType`
    else
      begin
        Net::SSH.start @options[:host], @options[:username] do |ssh|
          data = ssh.exec!('system_profiler -json SPMemoryDataType')
        end
      rescue
        @logger.error 'Remote host is not available'
      end
    end

    data
  end

  def parse(data)
    begin
      parsed_data = JSON.parse data
    rescue
      @logger.error 'Invalid captured data'
      return
    end

    root = parsed_data['SPMemoryDataType']

    if root.nil?
      @logger.error 'Invalid root'
      return
    elsif !root.is_a?(Array)
      @logger.error 'Invalid root object'
      return
    end

    root.each_with_index do |memory_data, idx|
      group_name = memory_data['_name'] || 'Unknown'

      memory_data_items = memory_data['_items']

      if memory_data_items.nil?
        @logger.error "Invalid group \"#{group_name}\""
      elsif !memory_data_items.is_a?(Array)
        @logger.error "Invalid group object \"#{group_name}\""
      else
        statuses = []
        has_error = false

        memory_data_items.each_with_index do |dimm_data, idx|
          name = dimm_data['_name'] || "Unknown #{idx}"
          status = dimm_data['dimm_status'] || 'Unknown'

          statuses << "#{name}: #{status}"

          unless status == 'ok'
            has_error = true
          end
        end

        message = "#{group_name}: #{statuses.join(', ')}"

        log_level = has_error ? Logger::ERROR : Logger::INFO
        @logger.log log_level, message
      end
    end
  end
end

runner = Runner.new options
runner.run

