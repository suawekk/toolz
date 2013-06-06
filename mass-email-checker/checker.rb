#!/usr/bin/env ruby
# vim:sw=2:ts=2:et:enc=utf8
# encoding: utf-8

# Ruby mass email checker
# version: 0.1
#
# Author:: suawekk <suawekk+github@gmail.com>
# License:: Distributed under the same terms as Ruby, I sincerely don't care about someone 'stealing' my code...

begin
  require 'rubygems'
  require 'bundler/setup'
  require 'colorize'
  require 'heredoc_unindent'
rescue => e
  STDERR.puts "Exception: #{e.message} occurred when loading required gems and files!"
  exit 1
end


module MassEmailChecker

  # This class encapsulates all of this script functionality
  class Checker

    #Default config file path
    DEFAULT_CONFIG = 'config.yml'
    DEFAULT_TARGETS = 'targets.yml'

    #Takes care of initialization tasks and their order
    def initialize
      @options = parse_options
      @targets    = load_targets

    end


    def parse_options
      OptionParser.new do |opts|
        output = {
          :config => DEFAULT_CONFIG,
          :targets => DEFAULT_TARGETS
        }

        opts.on '-c','--config [CONFIG]','Custom configuration file to use' do |cfg|
          unless File.exists?(cfg) 
            print_warning("Requested configuration file: #{cfg} does not exist!, reverting to default")
          else
            output[:config] = cfg
          end
        end

        opts.on '-t','--targets TARGETS','Target list (YAML format)' do |targets|


        end

        opts.parse!

        output
      end
    end

    #Loads configuration (if any)
    def load_config


    end

    #Perform basic checks whether loaded configuration is usable
    def config_valid?

    end

    #Do actual processing
    def run!

    end

    def print_warning(str)
      STDERR.puts(str.colorize(:orange))
    end
    def print_error(str)
      STDERR.puts(str.colorize(:red))
    end

  end


  Checker.new.run!
end
