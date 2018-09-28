# coding: utf-8
#
# This file is part of JiraScan
# https://github.com/bcoles/jira_scan
#

require 'uri'
require 'cgi'
require 'json'
require 'net/http'
require 'openssl'

class JiraScan
  VERSION = '0.0.1'.freeze

  #
  # Check if Jira
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.isJira(url)
    url += '/' unless url.to_s.end_with? '/'
    res = self.sendHttpRequest("#{url}secure/Dashboard.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include? 'JIRA'
  end

  #
  # Get Jira version
  #
  # @param [String] URL
  #
  # @return [String] Jira version
  #
  def self.getVersion(url)
    url += '/' unless url.to_s.end_with? '/'
    res = self.sendHttpRequest("#{url}secure/Dashboard.jspa")

    return unless res
    return unless res.code.to_i == 200

    version = res.body.to_s.scan(%r{<meta name="ajs-version-number" content="([\d\.]+)">}).flatten.first
    build = res.body.to_s.scan(%r{<meta name="ajs-build-number" content="(\d+)">}).flatten.first

    unless version && build
      if res.body.to_s =~ /Version: ([\d\.]+)-#(\d+)/
        version = $1
        build = $2
      else
        return
      end
    end

    "#{version}-##{build}"
  end

  #
  # Check if dev mode is enabled
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.devMode(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest(url)

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include? '<meta name="ajs-dev-mode" content="true">'
  end

  #
  # Check if account registration is enabled
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.userRegistration(url)
    url += '/' unless url.to_s.end_with? '/'
    res = self.sendHttpRequest("#{url}secure/Signup!default.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include? '<h1>Sign up</h1>'
  end

  #
  # Check if unauthenticated access to User Picker is allowed
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.userPicker(url)
    url += '/' unless url.to_s.end_with? '/'
    res = self.sendHttpRequest("#{url}secure/popups/UserPickerBrowser.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include? '<h1>User Picker</h1>'
  end

  #
  # Retrieve list of users
  #
  # @param [String] URL
  #
  # @return [Array] list of first 1,000 users
  #
  def self.getUsers(url)
    url += '/' unless url.to_s.end_with? '/'
    max = 1_000
    res = self.sendHttpRequest("#{url}secure/popups/UserPickerBrowser.jspa?max=#{max}")

    return [] unless res && res.code.to_i == 200 && res.body.to_s.include?('<h1>User Picker</h1>')

    users = []
    if res.body.to_s.include? 'cell-type-email'
      res.body.to_s.scan(%r{<td data-cell-type="name" class="user-name">(.*?)</td>\s+<td data-cell-type="fullname" >(.*?)</td>\s+<td data-cell-type="email" class="cell-type-email">(.*?)</td>}m).each do |u|
        users << u
      end
    else
      res.body.to_s.scan(%r{<td data-cell-type="name" class="user-name">(.*?)</td>\s+<td data-cell-type="fullname" >(.*?)</td>}m).each do |u|
        users << u
      end
    end

    users
  rescue
    []
  end

  #
  # Retrieve list of popular filters
  #
  # @param [String] URL
  #
  # @return [Array] list of popular filters
  #
  def self.getPopularFilters(url)
    url += '/' unless url.to_s.end_with? '/'
    res = self.sendHttpRequest("#{url}secure/ManageFilters.jspa?filter=popular&filterView=popular")

    if res && res.code.to_i == 200 && res.body.to_s.include?('<h1>Manage Filters</h1>')
      if res.body.to_s =~ /requestId=\d/
        return res.body.to_s.scan(%r{requestId=\d+">(.+?)</a>})
      elsif res.body.to_s =~ /filter=\d/
        return res.body.to_s.scan(%r{filter=\d+">(.+?)</a>})
      end
    end

    []
  end

  #
  # Retrieve list of dashboards
  #
  # @param [String] URL
  #
  # @return [Array] list of dashboards
  #
  def self.getDashboards(url)
    url += '/' unless url.to_s.end_with? '/'
    max = 1_000
    res = self.sendHttpRequest("#{url}rest/api/2/dashboard?maxResults=#{max}")

    return [] unless res && res.code.to_i == 200 && res.body.to_s.start_with?('{"startAt"')

    JSON.parse(res.body.to_s, symbolize_names: true)[:dashboards].map {|d| [d[:id], d[:name]] }
  rescue
    []
  end

  private

  #
  # Fetch URL
  #
  # @param [String] URL
  #
  # @return [Net::HTTPResponse] HTTP response
  #
  def self.sendHttpRequest(url)
    target = URI.parse(url)
    puts "* Fetching #{target}" if $VERBOSE
    http = Net::HTTP.new(target.host, target.port)
    if target.scheme.to_s.eql?('https')
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    http.open_timeout = 20
    http.read_timeout = 20
    headers = {}
    headers['User-Agent'] = "JiraScan/#{VERSION}"
    headers['Accept-Encoding'] = 'gzip,deflate'

    begin
      res = http.request(Net::HTTP::Get.new(target, headers.to_hash))
      if res.body && res['Content-Encoding'].eql?('gzip')
        sio = StringIO.new(res.body)
        gz = Zlib::GzipReader.new(sio)
        res.body = gz.read
      end
    rescue Timeout::Error, Errno::ETIMEDOUT
      puts "- Error: Timeout retrieving #{target}" if $VERBOSE
    rescue => e
      puts "- Error: Could not retrieve URL #{target}\n#{e}" if $VERBOSE
    end
    puts "+ Received reply (#{res.body.length} bytes)" if $VERBOSE
    res
  end
end
