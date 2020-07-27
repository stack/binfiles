#!/usr/bin/env ruby
#encoding: utf-8
#frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class Controller

  def initialize(ip_address)
    @http = Net::HTTP.new(ip_address, 9091)
    @session = nil
  end

  def get_torrents
    body = { method: 'torrent-get', arguments: { fields: ['id', 'name'] } }

    response = post(body)
    json = JSON.parse(response.body)

    if json['result'] == 'success'
      json['arguments']['torrents']
    else
      nil
    end
  end

  def start_torrents
    body = { method: 'torrent-start-now', arguments: { } }

    response = post(body)
    json = JSON.parse(response.body)

    if json['result'] == 'success'
      true
    else
      false
    end
  end

  def stop_torrents
    body = { method: 'torrent-stop', arguments: { } }

    response = post(body)
    json = JSON.parse(response.body)

    if json['result'] == 'success'
      true
    else
      false
    end
  end


  private

  def post(body, first_request = true)
    request = Net::HTTP::Post.new('/transmission/rpc')
    request.content_type = 'application/json'
    request.body = body.to_json

    request['X-Transmission-Session-Id'] = @session unless @session.nil?

    response = @http.request request

    if response.code == '409'
      if first_request
        @session = response['X-Transmission-Session-Id']
        return post(body, false)
      else
        raise 'Did not receive a session id'
      end
    elsif response.code != '200'
      raise "Fatal error attempting to communicate: #{response.code}: #{response.body}"
    else
      return response
    end
  end
end

ip_address = ARGV[0] || '127.0.0.1'
controller = Controller.new ip_address

response = controller.get_torrents
puts response.inspect

response = controller.start_torrents
puts response.inspect
