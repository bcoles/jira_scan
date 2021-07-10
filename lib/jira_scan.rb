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
  VERSION = '0.0.3'.freeze

  #
  # Check if URL is running Jira using Login page
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.detectJiraLogin(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}login.jsp")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include?('JIRA')
  end

  #
  # Check if URL is running Jira using Dashboard page
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.detectJiraDashboard(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/Dashboard.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include?('JIRA')
  end

  #
  # Get Jira version from Dashboard page
  #
  # @param [String] URL
  #
  # @return [String] Jira version
  #
  def self.getVersionFromDashboard(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/Dashboard.jspa")

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
  # Get Jira version from Login page
  #
  # @param [String] URL
  #
  # @return [String] Jira version
  #
  def self.getVersionFromLogin(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}login.jsp")

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

    res.body.to_s.include?('<meta name="ajs-dev-mode" content="true">')
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
    res = sendHttpRequest("#{url}secure/Signup!default.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include?('<h1>Sign up</h1>')
  end

  #
  # Check if unauthenticated access to UserPickerBrowser.jspa is allowed
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.userPickerBrowser(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/popups/UserPickerBrowser.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include?('<h1>User Picker</h1>')
  end

  #
  # Retrieve list of users from UserPickerBrowser
  #
  # @param [String] URL
  #
  # @return [Array] list of first 1,000 users
  #
  def self.getUsersFromUserPickerBrowser(url)
    url += '/' unless url.to_s.end_with? '/'
    max = 1_000
    res = sendHttpRequest("#{url}secure/popups/UserPickerBrowser.jspa?max=#{max}")

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
  # Check if unauthenticated access to REST UserPicker is allowed (CVE-2019-3403)
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.restUserPicker(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}rest/api/latest/user/picker")

    return false unless res
    return false unless res.code.to_i == 400

    res.body.to_s.include?('The username query parameter was not provided')
  end

  #
  # Check if unauthenticated access to REST GroupUserPicker is allowed (CVE-2019-8449)
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.restGroupUserPicker(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}rest/api/latest/groupuserpicker")

    return false unless res
    return false unless res.code.to_i == 400

    res.body.to_s.include?('The username query parameter was not provided')
  end

  #
  # Check if unauthenticated access to ViewUserHover.jspa is allowed (CVE-2020-14181)
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.viewUserHover(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/ViewUserHover.jspa")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.include?('User does not exist')
  end

  #
  # Check if META-INF contents are accessible (CVE-2019-8442)
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.metaInf(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}s/#{rand(36**6).to_s(36)}/_/META-INF/maven/com.atlassian.jira/atlassian-jira-webapp/pom.xml")

    return false unless res
    return false unless res.code.to_i == 200

    res.body.to_s.start_with?('<project')
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
    res = sendHttpRequest("#{url}secure/ManageFilters.jspa?filter=popular&filterView=popular")

    return [] unless res
    return [] unless res.code.to_i == 200
    return [] unless res.body.to_s.include?('<h1>Manage Filters</h1>')

    return res.body.to_s.scan(%r{requestId=\d+">(.+?)</a>}) if res.body.to_s =~ /requestId=\d/
    return res.body.to_s.scan(%r{filter=\d+">(.+?)</a>}) if res.body.to_s =~ /filter=\d/

    []
  rescue
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
    res = sendHttpRequest("#{url}rest/api/2/dashboard?maxResults=#{max}")

    return [] unless res
    return [] unless res.code.to_i == 200
    return [] unless res.body.to_s.start_with?('{"startAt"')

    JSON.parse(res.body.to_s, symbolize_names: true)[:dashboards].map {|d| [d[:id], d[:name]] }
  rescue
    []
  end

  #
  # Retrieve list of field names from QueryComponent!Default.jspa (CVE-2020-14179)
  #
  # @param [String] URL
  #
  # @return [Array] list of field names
  #
  def self.getFieldNamesQueryComponentDefault(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/QueryComponent!Default.jspa")

    return [] unless res
    return [] unless res.code.to_i == 200
    return [] unless res.body.to_s.start_with?('{"searchers"')

    searchers = JSON.parse(res.body.to_s)["searchers"]
    return [] if searchers.empty?

    groups = searchers['groups']
    return [] if groups.empty?

    field_names = []
    groups.each do |g|
      g['searchers'].each do |s|
        field_names << s
      end
    end

    JSON.parse(field_names.to_json, symbolize_names: true).map {|f| [f[:name], f[:id], f[:key], f[:isShown].to_s, f[:lastViewed]] }
  rescue
    []
  end

  #
  # Retrieve list of field names from QueryComponent!Jql.jspa (EDB-49924)
  #
  # @param [String] URL
  #
  # @return [Array] list of field names
  #
  def self.getFieldNamesQueryComponentJql(url)
    url += '/' unless url.to_s.end_with? '/'
    res = sendHttpRequest("#{url}secure/QueryComponent!Jql.jspa?jql=")

    return [] unless res
    return [] unless res.code.to_i == 200
    return [] unless res.body.to_s.start_with?('{"searchers"')

    searchers = JSON.parse(res.body.to_s)["searchers"]
    return [] if searchers.empty?

    groups = searchers['groups']
    return [] if groups.empty?

    field_names = []
    groups.each do |g|
      g['searchers'].each do |s|
        field_names << s
      end
    end

    JSON.parse(field_names.to_json, symbolize_names: true).map {|f| [f[:name], f[:id], f[:key], f[:isShown].to_s, f[:lastViewed]] }
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
      http.verify_mode = @insecure ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
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
