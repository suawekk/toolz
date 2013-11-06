#!/usr/bin/env ruby
################################################################################
# Hetzner failover switcher script
# Author:: Sławomir Kowalski <suawekk+github@gmail.com>
# Version:: 0.1
################################################################################

# Load required gems
begin
    require 'hetzner-api'
    require 'optparse'
    require 'rubygems'
    require 'yaml'
    require 'resolv'
    require 'colorize'
    require 'heredoc_unindent'
rescue => e
    STDERR.puts "Exception occured when loading required gems: #{e.message}"
    exit 1
end

class HetznerFailoverSwitcher

    def initialize
        @pad_length = 10
        @verbose = false
        @force   = false

        parse_args

        exit 1 unless check_args

        init_client
        run!
    end

    def run!
        target = get_target @ip

        unless check_result target
            exit 1
        end

        if target['error'].nil?
            ok "Successfully got failover config!"
        else
            process_error target['error']
            exit 1
        end

        if target['failover']['active_server_ip'].to_s  ==  @target
            error "#{@ip} is already routed to #{@target}!"
            exit 1
        end

        if (@verbose)
            info "Current failover config is: \n#{JSON.pretty_generate(target)}"
        else
            info "Current failover target is: #{target['failover']['active_server_ip']}"
        end

        unless @force
            warn "Do you really want to route #{@ip} to #{@target} (y/n , confirm with [ENTER]) ?"
            require_confirmation   
        end

        info "Trying to route  #{@ip} to #{@target}..."
        result = switch @ip,@taerget

        unless check_result result
            exit 1
        end

        if target['error'].nil?
            ok "Successfully switched failover target!"
        else
            process_error target['error']
            exit 1
        end
    end


    def check_result(hash)
        if target == false 
            error("Unable to get routing target!")
        end

        unless target.instance_of?(Hash)
            error "Result is not a hash! Probably API has changed."

            if (@verbose)
                info "Result was:\n" + target.to_s
            end
            return false
        end
        return true
    end

    def process_error(error)
        if error['status'] == 401
            error "API authorization failed!"
        elsif error['status'] == 403
            error "Request limit exceeded!"
        elsif error['status'] == 404
            error "Failover IP : #{@ip} not found!"
        elsif error['status'] == 503
            error "API server is in maintenance!"
        else
            error "API returned unknown status: #{error['status']}, code: #{error['code']}"
        end
    end

    def require_confirmation
        decision = nil
        decisions = ['y','n']

        while !decisions.include?(decision)

            unless decision.nil?
                error "Invalid data entered. try again, allowed combinations are y/n + [ENTER] !"
            end

            #let's make a prompt for user
            STDOUT.print '>'
            STDOUT.flush
            decision = STDIN.gets.gsub(/[[:space:]]/,'')
        end

        if decision == 'n'
            info "Aborted by user."
            exit 0
        end

        info "Operation confirmed"
    end

    

    def parse_args
        OptionParser.new do |options|
            options.on('-c','--config CONFIG') do |config|

                unless config.length
                    error("Provide config path: #{config} (-c )!")
                    exit 1
                end

                unless load_config(config) && check_config(@config)
                    exit 2
                end
            end

            options.on('-i','--ip IP') do |ip|
                if valid_ipv4(ip)
                    @ip = ip
                else
                    error("Passed invalid IP address: #{ip}! (-i)")
                end
            end

            options.on('-t','--target TARGET') do |target|
                if valid_ipv4(target)
                    @target = target
                else
                    error("Passed invalid IP address: #{target}! (-t)")
                end
            end

            options.on('-v','--verbose') do
                @verbose = true
            end

            options.on('-f','--force') do
                @force = true
            end

        end.parse!
    end

    def load_config(file)
        begin
            config = YAML.load_file(file)
        rescue => e
            error("Failed to load configuration, exception raised: #{e.message}")
            return false
        end

        @config = config
        true
    end

    def check_config(config)
        if config.nil?
            error("Invalid or empty config!")
            return false
        elsif config['username'].nil?
            error ("Config doesn't contain username!")
            return false
        elsif config['password'].nil?
            error("Config doesn't contain password") 
            return false
        end

        return true
    end

    def check_args
        if @target.nil?
            error "No target IP (-t) passed!"
            return false
        end

        if @ip.nil?
            error "No failover IP (-i)  passed!"
            return false
        end

        return true
    end

    def init_client
        begin
            @api = Hetzner::API.new @config['username'], @config['password']
        rescue => e
            error("Failed to initialize API client: #{e.message}")
            return false
        end
        true
    end

    
    def valid_ipv4(subject)
        return !(Resolv::IPv4::Regex =~ subject).nil?
    end

    def get_target(ip)
        begin
            target = @api.failover? ip
        rescue => e
            error("Exception when trying to examine #{ip}'s routing target: #{e.message}")
            return false
        end

        return target
    end

    def switch(ip,target)
        begin
            result = @api.failover! ip, target
        rescue => e
            error("Exception when trying to set  #{ip}'s routing target to #{target} : #{e.message}")
            return false
        end
            
        return result
    end

    def pad_msg_title(title,pad_len)
        title.rjust(pad_len)
    end

    def out_stderr_msg(title,color,msg,pad_len=@pad_length)
        STDERR.puts(pad_msg_title(title,pad_len).colorize(color) + ' ' + msg)
    end

    def error(str)
        out_stderr_msg("ERROR:",:red,str);
    end

    def info(str)
        out_stderr_msg("INFO:",:blue,str);
    end

    def ok(str)
        out_stderr_msg("OK:",:green,str);
    end

    def warn(str)
        out_stderr_msg("WARNING:",:yellow,str);
    end

end

HetznerFailoverSwitcher.new
