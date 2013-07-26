#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'etc'

module StatChecker

    EXIT_OK       = 0
    EXIT_WARNING  = 1
    EXIT_CRITICAL = 2
    EXIT_UNKNOWN  = 3

    FTYPE_DIR     = "dir"
    FTYPE_FILE    ="file"

    class StatChecker

        def initialize
            @opts = {}
        end

        def parse_args

            OptionParser.new do |parser|
                parser.on("-c","--config CONFIG","Configuration file") do |c|
                    @opts[:config] = c
                end
            end.parse!


            if @opts[:config].nil?
                puts "No configuration file specified"
                exit EXIT_UNKNOWN
            end
        end

        def load_config(path)
            cfg = nil
            begin
                File.open(path) {|f| cfg = JSON.parse(f.read)}
            rescue JSON::ParserError => e
                @errorstr = "Failed to parse configuration"
                return nil
            rescue =>e
                @errorstr = "Failed to load configuration"
                return nil
            end
            cfg
        end

        def match_files(glob_pattern,config)

            files = Dir[glob_pattern]

            results = []

            files.each {|f| results << process_file(f,config)}

            results
        end

        def process_file(name,config)
            stat = File.stat(name)

            result = {:name => name,:failed_attrs => []}

            unless stat
                result[:failures] << "stat"
            end

            begin
                user_data  = Etc::getpwnam(config['user'])
            rescue 
                user_data = nil
            end

            unless user_data && (user_data.uid == stat.uid)
                result[:failed_attrs] << "user != '#{config['user']}'"
            end

            begin
                group_data = Etc::getgrnam(config['group'])
            rescue 
                group_data=nil
            end

            unless group_data && (group_data.gid == stat.gid)
                result[:failed_attrs] << "group != #{config['group']}"
            end

            if config['type'] == FTYPE_DIR
                if !stat.directory? 
                    result[:failed_attrs] << "type != dir"
                end
            elsif config['type'] == FTYPE_FILE 
                if !stat.file?
                    result[:failed_attrs] << "type != file"
                end
            end

            actual_perms =  sprintf("%o",stat.mode)
            if  actual_perms != config['perm']
                    result[:failed_attrs] << "mode != #{config['perm']}"
            end

            result
        end

        def run!
            parse_args

            cfg = load_config(@opts[:config])

            unless cfg
                STDERR.puts(@errorstr)
                exit EXIT_UNKNOWN
            end

            failed = []

            cfg.each_pair do |glob_pattern,conditions|
                failed |= match_files(glob_pattern,conditions)
            end

            if failed.empty?
                puts "OK: no files have incorrect metadata"
                exit EXIT_OK
            end

            output = "CRITICAL: following files have invalid metadata:\n"
            failed.each do |f|
                output += ("%s: %s\n" % [f[:name],f[:failed_attrs].join(", ")])
            end

            puts output
            exit EXIT_CRITICAL
        end

    end
    StatChecker.new.run!
end

