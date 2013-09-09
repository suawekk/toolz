#!/usr/bin/env ruby
# vim:sw=2:ts=2:et

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
  require 'curb'
  require 'socksify/http'
  require 'pp'
  require 'optparse'
  require 'yaml'
  require 'net/pop'
  require 'net/imap'
  require 'net/http'
  require 'uri'
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
    DEFAULT_STATEFILE = 'state.yml'

    #Takes care of initialization tasks and their order
    def initialize
      parse_options
      load_configs
      show_targets
      load_statefile

      if (@options[:debug])
        Net::IMAP.debug = true
      end
    end


    def get_mailbox_state(mailbox_name)
      if @mailbox_state.nil?
        load_statefile
      end

      if @mailbox_state == false || @mailbox_state.nil?
        @mailbox_state = {}
      end

      unless @mailbox_state.has_key?(mailbox_name)
        @mailbox_state[mailbox_name] = Hash.new
      end

      return @mailbox_state[mailbox_name]
    end

    def set_mailbox_state(mailbox_name,last_uid)
      @mailbox_state[mailbox_name] = {
        'last_uid' => last_uid,
        'last_update' => DateTime.now.rfc2822  
      }

      write_statefile
    end


    def load_statefile
      @mailbox_state = YAML.load(File.open(@options[:statefile]))
      if @mailbox_state == false
        @mailbox_state = Hash.new
      end
    end

    def write_statefile
      File.open(@options[:statefile],'w') do |f|
        f.flock(File::LOCK_EX)
        f.write(YAML.dump(@mailbox_state))
        f.flock(File::LOCK_UN)
      end
    end


    def parse_options
      parser = OptionParser.new do |opts|
        @options = {
          :config     => DEFAULT_CONFIG,
          :targets    => DEFAULT_TARGETS,
          :statefile  => DEFAULT_STATEFILE,
          :debug      => false
        }

        opts.on '-c','--config [CONFIG]','Custom configuration file to use' do |cfg|
          unless File.exists?(cfg) 
            print_warning("Requested global configuration file: #{cfg} does not exist!, reverting to default")
          else
            @options[:config] = cfg
          end
        end

        opts.on '-t','--targets TARGETS','Target list (YAML format)' do |targets|
          unless File.exists?(targets) 
            print_warning("Requested targets configuration file: #{targets} does not exist!, reverting to default")
          else
            @options[:targets] = targets
          end

        end

        opts.on '-s','--statefile TARGETS','state file (YAML format)' do |state|
          unless File.exists?(targets) 
            print_warning("Requested state configuration file: #{state} does not exist!, reverting to default")
          else
            @options[:statefile] = state
          end

        end

        opts.on('-d','--debug','Enable debbuging informations') {@options[:debug] = true}
      end

      parser.parse!
    end

    #Loads global and target configuration
    def load_configs
      @config = YAML.load(File.open(@options[:config]))
      @targets = YAML.load(File.open(@options[:targets]))
      @state = YAML.load(File.open(@options[:statefile]))
    end

    def show_targets
      i = 0
      puts "Targets: "
      @targets.each_pair do |target_name,target_opts|
        puts "##{i += 1} %s (%s)" % [target_name,target_opts['email']]
      end

    end


    def test_target(target)

    end

    def retrieve_mails(target)
      if (target['type'] == 'imap')
        return retrieve_imap(target)
      elsif (target['type'] == 'pop3')
        return retrieve_pop3(target)
      else
        raise "Unsupported mailbox type: #{target['type']} !"
        return nil
      end
    end

    def retrieve_imap(target)
      #begin
      conn  = Net::IMAP.new(target['server'],{
        :ssl => { 
        :ca_file     => @config['general']['bundle'],
        :verify_mode => @config['general']['ssl_verify'] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE 
      },port: target['port']}) 


      if target['plaintext_login']
        begin
          conn.login(target['username'],target['password'])
        rescue => e
          puts "Failed to login as #{target.username}@#{target['server']}:#{target['port']} #{target['ssl'] ? 'using ssl' : ''}. Raised exception: #{e.message}"
          return nil
        end
        puts "Logged in using plain LOGIN..."
      else
        raise "Only plaintext logins are supported! (SSL is used almost everywhere...) - Sorry!"
        return nil
      end

      mailboxes = retrieve_imap_mailboxes(conn)

      if @options[:debug]
        STDERR.puts "Available mailboxes are: #{mailboxes.join(',')}"
      end


      unless mailboxes.include?(target['mailbox'])
        puts "No such mailbox: #{target['mailbox']}"
        return nil
      end

      puts "Checking mailbox: #{target['mailbox']}"

      conn.select(target['mailbox'])


      mailbox_state = get_mailbox_state(target['email'])

      search_query = nil
      if mailbox_state.nil? || mailbox_state.empty? || mailbox_state['last_uid'].nil?
        search_query = ['ALL']
      else
        last_seen_uid = mailbox_state['last_uid']
        search_query = [ "#{last_seen_uid + 1}:*" ]
      end

      ids = conn.uid_search(search_query)

      unless ids.nil? || !ids.kind_of?(Array) || ids.count == 0
        set_mailbox_state(target['email'],ids.max)
      end

      if ids.empty?
        puts "Mailbox '#{target['mailbox']}' doesn't have any unprocessed messages!"
        return nil
      else
        puts "Mailbox '#{target['mailbox']}' has #{ids.count} messages to process ..."
      end

      results = []
      ids.each do |msg_id|
        begin
          msg_data = conn.uid_fetch(msg_id,['RFC822.HEADER','RFC822.TEXT','ENVELOPE'])
        rescue => e
          STDERR.puts "Exception raised during fetching email with ID=#{msg_id} !"
          next
        end

        msg = msg_data.pop
        #TODO: do actual processing here
        results <<  
        {
          'body'    => Net::IMAP::decode_utf7(msg.attr['RFC822.TEXT']),
          'hdr'     => msg.attr['RFC822.HEADER'],
          'sender'  => imap_addr_to_str(msg.attr['ENVELOPE'].sender.pop),
          'rcpt'    => imap_addr_to_str(msg.attr['ENVELOPE'].to.pop),
          'subject' => msg.attr['ENVELOPE'].subject ?   Net::IMAP::decode_utf7(msg.attr['ENVELOPE'].subject) : nil,
        }

      end

      return results
      #rescue => e
      #  STDERR.puts "Failed to check mailbox: #{target['email']}, Error: #{e.to_s}!"
      #end
    end

    def retrieve_imap_mailboxes(conn)
      result = []
      conn.list('','*').each {|v| result << v.name}
      result
    end

    def imap_addr_to_str(addr)
      nil unless addr.kind_of?Net::IMAP::Address
      "<%s@%s>" % [
        Net::IMAP::decode_utf7(addr['mailbox']),
        Net::IMAP::decode_utf7(addr['host'])
      ]
    end



    #Do actual processing
    def run!
      @targets.each_pair do |target_name,target|
        puts "Processing #{target_name} (#{target['email']}) [#{target['type'].upcase}] ..."
        mails = retrieve_mails(target)
        next unless mails

        mails.each do |mail|
          puts "Processing message from: %s, subj:%s" % [mail['sender'],mail['subject']]
          process_patterns(mail['body'],target['pattern_actions'])
        end
      end
    end

    def print_warning(str)
      STDERR.puts(str.colorize(:orange))
    end

    def print_error(str)
      STDERR.puts(str.colorize(:red))
    end

    def preprocess_body(msg_body)
      #TODO: do actual preprocessing here...

      msg_body
    end


    def process_patterns(msg_body,action_map)
      if action_map.empty?
        puts "No patterns defined..."
        return nil
      end

      #puts "Processing #{action_map.count} patterns"
      action_map.each_pair do |pattern,actions|

        re = Regexp.new(pattern);
        #puts "Matching body against #{re.source}"

        msg_body.scan(re) do |match|
          match.unshift
          actions.each do |action|
            puts "Found match for #{re.source} : #{match}, calling action: #{action}"
            self.send(action,match)
          end
        end
      end
    end

    def click_first_link(urls)
      unless urls.kind_of?(Array) && urls.count
        return nil
      end

      url = urls.pop
      puts "Clicking first url: #{url}"
      get_url(url)
    end

    def get_url(uri)
      parsed_uri = URI.parse(uri)
      #begin
        if @config['proxy']['enable']
          Net::HTTP.SOCKSProxy(@config['proxy']['server'], @config['proxy']['port']).start(parsed_uri.host,parsed_uri.port) do |http|
            doc = http.get(parsed_uri.path)

            unless doc == nil
              return doc.body
            end
            return doc
          end
        else
          return Net::HTTP.get_response(parsed_uri)
        end
      #rescue => e
        print_error("Failed to fetch #{uri} with exception: #{e.message}")
        return nil
      #end
    end
  end

  Checker.new.run!
end
