#!/usr/bin/env ruby
# Pingdom REST API paused/failed check tester 
# Author: suawekk <suawekk+nagioschecks@gmail.com>
# Ver: 0.1
# Date: 2013-04-26

begin
    require 'curb'
    require 'set'
    require 'json'
    require 'heredoc_unindent'
    require 'nagios_check'
rescue LoadError => e
    puts "Exception was raised when loading required gems: #{e.message}"
end

class PingdomCheck
    include NagiosCheck

    VERSION = '0.1'
    API_PROTO = 'https'
    API_BASE = 'api.pingdom.com/api'

    API_VER =  '2.0'
    API_KEY_HEADER = 'App-Key'
    API_USER_AGENT = "check_pingdom/#{VERSION}"

    STATUS_PAUSED = 'paused'
    STATUS_UP = 'up'
    STATUS_DOWN = 'down'

    on '--user USER', '-u USER',String, :mandatory
    on '--pass PASSWORD', '-p PASSWORD',String, :mandatory
    on '--apikey APIKEY', '-a APIKEY',String, :mandatory
    on '--mode MODE', '-m MODE',String, [:failed,:paused],:mandatory
    on '--help', '-h',String do 
        help
        exit 3
    end

    on '-g', '--gzip',:optional do
        @options[:gzip] = true
    end

    enable_timeout
    enable_warning
    enable_critical

    def help
        puts <<-EOD.unindent
            Usage: check_pingdom opts
            opts are:
                -m , --mode failed|paused 
                    determine which checks should be counted
                -u, --user USER 
                    Pingdom account username
                -p, --pass PASS
                    Pingdom account PASSWORD
                -a, --apikey APIKEY
                    Pingdom REST API key
                -h, --help
                    Shows this message...
                -w x|x,y
                    Warning range
                -c x|x,y
                    Critical range
                -t TIMEOUT_SECS
                    Optional timeout in seconds
        EOD
    end

    def check
        url= "#{API_PROTO}://#{API_BASE}/#{API_VER}/checks"

        curb = Curl::Easy.perform(url) do |c| 
            c.http_get
            c.http_auth_types = :basic
            c.follow_location  = true
            c.useragent = API_USER_AGENT
            c.headers["#{API_KEY_HEADER}"] = @options['apikey']
            c.username = @options['user']
            c.password = @options['pass']

            if @options['gzip']
                c.headers['Accept-Encoding'] = 'gzip'
            end
        end

        unless curb.response_code == 200
            raise "Server responded with code #{curb.response_code} when accessing #{url} !"
        end

        begin
            decoded = JSON.parse(curb.body_str)
        rescue JSON::ParserError => e
            raise "Failed to decode server response as JSON, exception was raised:  #{e.message}"
        end

        matches = Set.new

        mode = case @options['mode']
           when :failed then STATUS_DOWN
           else STATUS_PAUSED
        end

        mode_str = ((mode == STATUS_DOWN) ? 'failed' : 'paused')

        all = Set.new(decoded['checks'])

        all.each do |check|
            if check['status'] == mode
               matches << check
            end
        end

        if matches.empty?
            store_message "#{mode_str} checks: no matches"
        else
            matched_names = Array.new
            matches.each do |check|
                matched_names << check['name']
            end
            store_message "#{mode_str} checks: #{matched_names.join(',')}"
        end

        store_value :problems, matches.count 
    end
end

PingdomCheck.new.run
