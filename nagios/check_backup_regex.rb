#!/usr/bin/ruby
################################################################################
# Simple glob file checker
# searches for files  in dir passed as -d matching glob pattern : -n and
# no older than -c seconds
################################################################################
STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3

begin
    require 'date'
    require "getopt/std"
    require "heredoc_unindent"
rescue LoadError => e
    puts "UNKNOWN: script raised exception during loading requred gems: #{e.to_s} !"
    exit STATUS_UNKNOWN
end

def usage
   puts <<-END.unindent
       -----
       Usage: 
       check_backup_regex -d DIR -c CRIT_SECS -n NAME_REGEX -f DATE_FORMAT
       where:
          DATE_FORMAT is strptime-style date format
          DIR is directory to be searched
          CRIT_SECS critical threshold
          NAME_REGEX is regexp to match filenames against of
       -----
       See man 3 strptime to see date formatting help
   END
end

def my_error(string,code = STATUS_UNKNOWN)
    $stderr.puts string
    exit code
end

opt = Getopt::Std.getopts('d:c:n:f:h')

if opt.include?('h')  
   usage
   exit STATUS_UNKNOWN
end

unless opt.include?('d')   
   my_error "UNKNOWN: No directory passed ( -d )"
end

unless Dir.exists?(opt['d'])
    my_error "UNKNOWN: Directory: #{opt['d']} does not exist!"
end

$search_dir=opt['d']

unless opt.include?('n')   
   my_error "UNKNOWN: No name pattern passed ( -n )"
end

$name_pattern = opt['n']

unless opt.include?('f')   
   my_error "UNKNOWN: No pattern passed ( -f )"
end

$date_format = opt['f']

unless opt.include?('c')   
   my_error "UNKNOWN: No critical file age threshold passed ( -c )"
end

begin
    $critical_secs = Integer(opt['c'])
rescue ArgumentError
    my_error "UNKNOWN: Bad value for threshold value ( -c )!"
end

#Should not happen - value with hyphen will be treated as another
#getopt parameter...
if $critical_secs == 0
    my_error "UNKNOWN: threshold value (-c) should be >= 0"
end

$name_capture_regex = Regexp.new('(' + $name_pattern + ')')

if $name_capture_regex.nil? 
    my_error "Failed to create name pattern regexp object!"
end

#Glob for all files - results will be matched against regexp
glob_pattern =$search_dir + '/**/*'

matching_files = Dir[glob_pattern].select do |file| 
   filename = File.basename(file)
   matches = $name_capture_regex.match(filename)

   next(false) unless (!matches.nil? && matches.captures.length)

   #Try to parse filename as date 
   begin
        date = DateTime.strptime(filename,$date_format)
   rescue ArgumentError
        my_error "UNKNOWN: Bad date format, see strptime(3) man page!"
   end

   next(false) unless date

   #Calculate file age as indicated by date in filename
   ( Time.now.to_i - date.to_time.to_i ) <  $critical_secs
end

if matching_files.empty?
    puts "CRITICAL: No files matching /#{$name_pattern}/ and younger than #{$critical_secs} secs found!"
    exit STATUS_CRITICAL
else
    puts "OK: Found: #{matching_files.count} files matching /#{$name_pattern}/ and younger that #{$critical_secs} secs: #{matching_files.join(',')}"
    exit STATUS_OK
end

