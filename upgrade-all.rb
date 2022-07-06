#!/usr/bin/env ruby
#encoding: utf-8
#frozen_string_literal: true

#
#  upgrade-all.rb
#  binfiles
#
#  Created by Stephen H. Gerstacker on 2021-12-14.
#  Copyright © 2021 Stephen H. Gerstacker. All rights reserved.
#

require 'json'
require 'net/http'
require 'plist'
require 'uri'

# Helper for determining platform
module OS
  # Is the platform Windows?
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  # Is the platform macOS?
  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  # Is the platform UNIX-like?
  def OS.unix?
    !OS.windows?
  end

  # Is the platform Linux?
  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

# Helper for finding executables
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

class Update

  def self.can_run?
    return false
  end

  def description
    raise NotImplementedError
  end

  def icon
    raise NotImplementedError
  end

  def execute(command)
    result = system(command)
    result == true
  end

  def run
    raise NotImplementedError
  end

  def puts_bold(line)
    puts "\e[1m#{line}\e[0m"
  end

  def puts_green(line)
    puts "\e[32m#{line}\e[0m"
  end

  def puts_red(line)
    puts "\e[31m#{line}\e[0m"
  end

  def puts_yellow(line)
    puts "\e[33m#{line}\e[0m"
  end

  def puts_announcement
    puts_bold "#{icon} #{description}"
  end

  def puts_failure(line)
    puts_red "💥 #{line}"
  end

  def puts_success(line)
    puts_green "👍 #{line}"
  end

  def puts_warning(line)
    puts_yellow "⚠️  #{line}"
  end
end

class AptUpdate < Update

  def self.can_run?
    return false unless OS.linux?

    apt_command = which('apt') || which('apt-get')
    return false if apt_command.nil?

    true
  end

  def description
    'Apt updates'
  end

  def icon
    '🍄'
  end

  def run
    apt_command = which('apt') || which('apt-get')

    unless execute("sudo #{apt_command} update")
      puts_failure 'Failed to update Apt'
      return false
    end

    unless execute("sudo #{apt_command} upgrade")
      puts_failure 'Failed to upgrade Apt'
      return false
    end

    unless execute("sudo #{apt_command} autoremove")
      puts_failure 'Failed to clean Apt'
      return false
    end

    true
  end
end

class HomebrewUpdate < Update

  def self.can_run?
    return false if which('brew').nil?

    true
  end

  def description
    'Homebrew updates'
  end

  def icon
    '🍻'
  end

  def run
    unless execute('brew update')
      puts_failure 'Failed to update Homebrew'
      return false
    end

    unless execute('brew upgrade')
      puts_failure 'Failed to upgrade Homebrew'
      return false
    end

    unless execute('brew upgrade --cask')
      puts_failure 'Failed to upgrade Homebrew Casks'
      return false
    end

    unless execute('brew cleanup')
      puts_failure 'Failed to clean up Homebrew'
      return false
    end

    true
  end
end

class MacAppStoreUpdate < Update

  def self.can_run?
    return false unless OS.mac?
    return false if which('mas').nil?

    true
  end

  def description
    'Mac App Store updates'
  end

  def icon
    '📱'
  end

  def run
    unless execute('mas outdated')
      puts_failure 'Failed to update Mac App Store'
      return false
    end

    unless execute('mas upgrade')
      puts_failure 'Failed to upgrade Mac App Store'
      return false
    end

    true
  end
end

class MacOSUpdate < Update

  def self.can_run?
    return false unless OS.mac?
    return false if which('softwareupdate').nil?

    true
  end

  def description
    'macOS updates'
  end

  def icon
    '🍎'
  end

  def run
    unless execute('sudo softwareupdate -i -a')
      puts_failure 'Failed to update macOS'
      return false
    end

    true
  end
end

class RubyGemsUpdate < Update

  def self.can_run?
    return false if which('gem').nil?

    true
  end

  def description
    'Ruby Gem updates'
  end

  def icon
    '💎'
  end

  def run
    unless execute('gem update --system')
      puts_failure 'Failed to update Ruby Gem system'
      return false
    end

    unless execute('gem update')
      puts_failure 'Failed to update Ruby Gems'
      return false
    end

    true
  end
end

class RubyUpdate < Update

  def self.can_run?
    true
  end

  def description
    'Ruby updates'
  end

  def icon
    '♦️ '
  end

  def run
    uri = URI.parse 'https://www.ruby-lang.org/en/downloads/releases/'
    response = Net::HTTP.get_response uri

    if response.code != '200'
      puts_failure "Failed to get Ruby versions: #{response.code}"
      return false
    end

    in_releases = false

    releases = []
    current = {}

    ruby_regex = /Ruby (\d+\.\d+\.\d+)-?([^<]+)?/.freeze
    date_regex = />([^<]+)/.freeze
    link_regex = /href="([^"]+)"/.freeze

    response.body.each_line do |line|
      if in_releases
        if line.include?('</table>')
          in_releases = false
          break
        elsif line.include?('<tr')
          current = {}
        elsif line.include?('</tr>')
          next if current.empty?

          releases << current
          current = {}
        elsif current[:version].nil?
          current ||= {}

          line.match(ruby_regex) do |m|
            current[:version] = m[1]
            current[:version_extra] = m[2]
          end
        elsif current[:date].nil?
          line.match(date_regex) do |m|
            current[:date] = Date.parse(m[1])
          end
        elsif current[:link].nil?
          line.match(link_regex) do |m|
            current[:link] = "https://www.ruby-lang.org" + m[1]
          end
        end
      else
        if line.include?('<table') && line.include?('release-list')
          in_releases = true
        end
      end
    end

    full_releases = releases
      .select { |x| x[:version_extra].nil? || (!x[:version_extra].include?('preview') && !x[:version_extra].include?('rc')) }
      .sort_by { |x| x[:version] }
      .reverse

    latest_release = full_releases.first

    if latest_release.nil?
      puts_failure 'Failed to parse Ruby versions'
      return false
    end

    if latest_release[:version] != RUBY_VERSION
      puts_warning 'Ruby is not up to date!'

      unless latest_release[:link].nil?
        puts "🔗 News: #{latest_release[:link]}"
      end
    else
      puts_success 'Ruby is up to date'
    end

    true
  end
end

class RustUpdate < Update

  def self.can_run?
    return false if which('rustup').nil?

    true
  end

  def description
    'Rust updates'
  end

  def icon
    '🦀'
  end

  def run
    unless execute('rustup self update')
      puts_failure 'Failed to update Rustup'
      return false
    end

    unless execute('rustup update')
      puts_failure 'Failed to update Rust'
      return false
    end

    true
  end
end

class SnapUpdate < Update

  def self.can_run?
    return false unless OS.linux?
    return false if which('snap').nil?

    true
  end

  def description
    'Snap updates'
  end

  def icon
    '🤌 '
  end

  def run
    unless execute('sudo snap refresh')
      puts_failure 'Failed to refresh Snap'
      return false
    end

    true
  end
end

class XcodeUpdate < Update

  def self.can_run?
    return unless OS.mac?
    return unless Dir.exist?('/Applications/Xcode.app')

    true
  end

  def description
    'Xcode version'
  end

  def icon
    '⚒️ '
  end

  def run
    # Get the current installed version
    xcode_path = '/Applications/Xcode.app/Contents/version.plist'
    current_version_data = Plist.parse_xml xcode_path

    current_version = current_version_data['ProductBuildVersion']

    # Get the known released versions
    uri = URI.parse 'https://xcodereleases.com/data.json'
    response = Net::HTTP.get_response uri

    if response.code != '200'
      puts_failure 'Failed to get Xcode Releases API'
      return false
    end

    releases = JSON.parse response.body

    full_releases = releases.filter_map do |release|
      version = release['version']
      next if version.nil?

      build = version['build']
      next if build.nil?

      number = version['number']
      next if number.nil?

      release_dict = version['release']
      next if release_dict.nil?

      release_value = release_dict['release']
      next if release_value.nil?

      links = release['links']

      release_notes_url = nil
      download_url = nil

      unless links.nil?
        unless links['notes'].nil?
          unless links['notes']['url'].nil?
            release_notes_url = links['notes']['url']
          end
        end

        unless links['download'].nil?
          unless links['download']['url'].nil?
            download_url = links['download']['url']
          end
        end
      end

      if release_value
        { build: build, build_number: build.to_i(16), number: number, download: download_url, release_notes: release_notes_url }
      end
    end

    latest_release = full_releases.first

    if latest_release.nil?
      puts_failure 'Cannot find the latest release'
      return false
    end

    # Do the actual check
    if current_version != latest_release[:build]
      puts_warning 'Xcode is not up to date!'

      unless latest_release[:download].nil?
        puts "🔗 Download: #{latest_release[:download]}"
      end

      unless latest_release[:release_notes].nil?
        puts "📃 Release Notes: #{latest_release[:release_notes]}"
      end
    else
      puts_success 'Xcode is up to date'
    end

    true
  end
end

updates = [
  'MacOS', 'Xcode', 'MacAppStore', 'Homebrew', 'Apt', 'Snap', 'Ruby', 'RubyGems', 'Rust'
]

updates.each do |update|
  clazz = Object.const_get("#{update}Update")

  next unless clazz.can_run?

  update = clazz.new

  puts
  update.puts_announcement

  success = update.run

  exit 1 unless success
end

