#!/usr/bin/env ruby
#
# ruby gem checker by suawekk <suawekk@gmail.com>
# requirements:
#   -ruby (obviously...)
#   -'curb' gem
#   -'getopts' gem
#

begin
    require 'getopt/std'
rescue LoadError
    puts "Install 'getopt' gem first!"
    exit 1
end

begin
    require 'curb'
rescue LoadError
    puts "Install 'curb' gem first!"
    exit 1
end

$verbose = false
opts = Getopt::Std.getopts('hv')

if opts['h']
    puts <<-eos
Usage: #{$0} [-v]

This script reads list of urls from STDIN  and 
outputs data in format url|last_redirect_http_code to STDOUT
If '-v' was passed script will also output some debugging info to STDERR.
eos

    exit 
elsif opts['v']
    $verbose = true
end



def log(msg)
    if !$verbose 
        return
    end

    STDERR.puts("#{Time.now.to_s}:#{msg}")
end


multi = Curl::Multi.new
url_regex = /https?:\/\/.*/

STDIN.each_line do |line|
    url = line.strip

    if (!url_regex.match(url))
        log("#{url} doesn't look like URL")
        next
    end

    c = Curl::Easy.new(url) do |curl|
        log("Adding #{url}")
        curl.follow_location = true
        curl.on_complete { log("Request completed: #{url}"); puts "#{url}|#{curl.response_code}"}
    end

    multi.add(c)
end

multi.perform

