#!/usr/bin/env ruby
# encoding: utf-8

################################################################################
# FileChecker nagios check:
# Checks for files matching both passed filename pattern and modification time
################################################################################
begin
    require 'rubygems'
    require 'bundler/setup'
    require 'heredoc_unindent'
    require 'optparse'
    require 'chronic'
    require 'chronic_duration'
    require 'pp'
rescue LoadError => e
    STDERR.puts "exception raised when trying to load required gems: #{e.message}"
end

class FileChecker

    STATUS_OK = 0
    STATUS_WARN = 1
    STATUS_ERR = 2
    STATUS_UNKNOWN = 3

    def initialize
        parse_opts

    end

    def help
        puts <<-EOD.unindent
        File existence nagios check. Checks whether files in DIR matching REGEXP are newer that CRIT_SECS or WARN_SECS
        
        Usage: check_existence.rb -w WARN_SECS -c CRIT_SECS -d DIR -r REGEXP
        where:
            WARN_SECS: warning threshold in seconds
            CRIT_SECS: critical threshold in seconds
            DIR: directory where files are located
            REGEXP: regular expression which will be used to filter files
        EOD

        exit STATUS_UNKNOWN
    end

    def parse_opts

        @options = {
            :regex => nil,
            :warning => 3600,
            :critical => 300,
            :dir => nil
        }

         OptionParser.new do |opts|
            opts.on '-h', '--help','show help screen' do
                help
                exit 0
            end
            opts.on '-r','--regexp REGEXP','filter files by regular expression pattern' do |r|
                @options[:regexp] = Regexp.new(r)
                @options[:regexp] = Regexp.new(r)
            end

            opts.on '-w','--warning TIME','' do |w|
                @options[:warning] = ChronicDuration.parse(w)

            end

            opts.on '-c','--critical TIME','' do |c|
                @options[:critical] = ChronicDuration.parse(c)
            end

            opts.on '-d','--dir DIRECTORY','' do |d|
                @options[:dir] = d
            end

            opts.parse!
        end

    end

    def run!
        all_files = get_files(@options[:dir])
        filtered = filter_regex(all_files)
        results =  check_times(filtered)

        print_results(results)
    end

    def print_results(results)
        unless results.kind_of? Hash
            STDERR.puts "Internal error"
            exit STATUS_UNKNOWN
        end

        if results[:errors].count > 0
            puts "CHECK_EXISTENCE: Found #{results[:errors].count} errors: #{results[:errors].join(',')} were modified later than #{@options[:critical]} seconds ago."
            exit STATUS_ERR
        elsif results[:warnings].count > 0
            puts "CHECK_EXISTENCE: #{results[:warnings].count} warnings: #{results[:warnings].join(',')} were modified later than #{@options[:warning]} seconds ago."
            exit STATUS_WARN
        else
            puts "CHECK_EXISTENCE: #{results[:ok].count} ok: #{results[:ok].join(',')} were modified earlier than #{@options[:warning]} seconds ago"
            exit STATUS_OK
        end

    end

    def get_files(dir)
        Dir[File.join(dir,'*')]
    end

    def filter_regex(paths)
        paths.delete_if {|p| !File.basename(p).match(@options[:regexp]) }
    end

    def check_times(files)
        results = {
            :warnings => [],
            :errors => [],
            :ok => [],
            :total => files.count
        }

        curr_tstamp = Time.now.to_i

        files.each do |file|
            diff = curr_tstamp - File.mtime(file).to_i 

            if diff <= @options[:critical]
                results[:errors] << file
            elsif diff <= @options[:warning]
                results[:warnings] << file
            else
                results[:ok] << file
            end
        end

        return results
    end

end

FileChecker.new.run!
