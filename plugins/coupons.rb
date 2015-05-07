#encoding: utf-8

require 'mechanize'

module BotpopPlugins

  CONFIG = YAML.load_file('plugins/coupon_login.yml')['creditentials']

  USER = CONFIG['username']
  PASS = CONFIG['password']
  URL = "https://api.pathwar.net/organization-coupons/___COUPON___"
  def self.exec_coupon m
    coupon = m.params[1..-1].join(' ').gsub(/(coupon:)/, '').split.first
    coupon = coupon.gsub(/[^A-z0-9\.\-_]/, '') # secure a little

    begin
      uri = URI(URL.gsub('___COUPON___', coupon))
      req = Net::HTTP::Get.new(uri)
      req.basic_auth USER, PASS
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') {|http|
        @rep = http.request(req)
      }

      # `curl https://api.pathwar.net/organization-coupons/#{coupon} -u '#{USER}:#{PASS}' -X GET`
      STDERR.puts @rep.body
      m.reply "#{coupon} " + (@rep.code == '200' ? 'validated' : 'missed')
    rescue
      m.reply "#{coupon} buggy"
    end
  end

end
