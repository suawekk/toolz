#!/usr/bin/env ruby

require 'yaml'
require 'mail'

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNKNOWN=3

$config_filename="config.yml";
$config_file= File.join(File.dirname(File.expand_path(__FILE__)),$config_filename)
$config = YAML.load_file($config_file)

unless File.exists?($config_file)
	STDERR.puts("No such file: #{$config_file}!")
        exit 1
end
if  $config.nil?
	STDERR.puts("Failed to load config from #{$config_file}")
	exit 2
end

mail = Mail.read_from_string(STDIN.read)

if mail.nil?
	STDERR.puts("Failed to parse message");
	exit 3
end

matching = nil

$config['checks'].each_pair do |k,v|
	re = Regexp.new(v['from_pattern'])
	next unless re
	from = mail.from.pop

	if from =~ re
		matching = v
		break
	end
end

if matching.nil?
	STDERR.puts("No matching config");
	exit 0
end


ts=Time.now.to_i 
sent=mail.date.to_time.to_i
threshold = matching['late_delivery_secs'].to_i


code = EXIT_OK
threshold_passed = false

delay = ts - sent
if delay  > threshold
	threshold_passed=true
	code = EXIT_WARN
end


if (threshold_passed)
	prefix="CHECK_MAILING WARNING(late delivery)"
else
	prefix ="CHECK_MAILING OK"
end

details ="#{prefix}: Received mail from #{mail.from.pop}, at: #{mail.date}, subject: #{mail.subject},id: #{mail.message_id}, delayed by #{delay} seconds"
passive_check_submit_str="[%i] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%i;%s\n" % [ts,$config['submission']['hostname'],matching['svc_name'],code,details]


unless File.exists?($config['submission']['nagios_socket'])
	STDERR.puts("Nagios socket: #{$config['submission']['nagios_socket']} doesn't exist!") 
	exit 4
end

File.open($config['submission']['nagios_socket'],"w") do |sock|
	sock.write(passive_check_submit_str)
end


unless matching['log_file'].nil?
	File.open(matching['log_file'],"a") do |log|
		log.puts("%s: from %s,subj: %s,id:  %s, state: %i\n" % [Time.now.to_s,mail.from.pop,mail.subject,mail.message_id,code])
	end
end

exit 0

