### This script processes incoming messages and submits passive checks locally via nagios rw socket
### To use it you need to pipe incoming messages to STDIN 


#### Setup
In postfix you can put something like this in respective users' home directory:
`| /var/lib/nagios/check_mailings/check_mailings.rb`
assuming script is located at /var/lib/nagios/check_mailings/check_mailings.rb

#### Config
Configuration is done by editing config.yml file attached to script.
File is in YAML format and should be fairly easy to understand.

Each nagios check needs separate node under 'checks' key
containing at least two keys with respective values:
  * from_pattern  - pattern which sender address must match to trigger this check
  * svc_name - service name equal to one defined in Nagios

Optional keys are:
 * log_file - log file for service - script will append one line with message details for each matched image

Configuration also has 'global' section.
Its keys will overwrite non-existing keys from per-check sections
Here you can configure 
 * header field names and regexes for SPF,DKIM and Spam filter  for valid/correct state

'Submission' section is obligatory and sets:
 * hostname - Nagios hostname (required by  passive check string format)
 * nagios_socket - Nagios socket which will accept passive check submissions


#### Runtime
script will check SPF, DKIM and Spam Filter headers against provided regexes (if any of those checks are enabled)
and whether message is late.

Critical condition will be submitted to nagios if  any of header checks failed
Warning condition will be submitted if delivery was late and no header checks failed
otherwise script will submit 'OK' for selected service
