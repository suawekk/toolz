#!/usr/bin/env python2

import getopt
import sys
import spf
from string import Template

opts,args = getopt.getopt(sys.argv[1:],"i:d:r:s:t:w")

ip              = None
domain          = None
sender          = None
code            = None
error           = False
warning_mode    = False
timeout         = 30
detail_template = "SPF record validation for domain=$domain,sender=$sender,ip=$ip returned: $code"

EXIT_OK         = 0
EXIT_WARNING    = 1
EXIT_CRITICAL   = 2
EXIT_UNKNOWN    = 3

rfc4408_codes = [
    'pass',
    'fail',
    'neutral',
    'softfail',
    'permerror',
    'temperror',
]

for key,val in opts:
    if key == "-i":
        ip = val
    elif key =="-d":
        domain = val
    elif key =="-s":
        sender = val
    elif key =="-r":
        code = val
    elif key =="-s":
        sender = val
    elif key =="-w":
        warning_mode = True
    elif key =="-t":
        timeout = val

if ip is None:
    print("No ip (-i) passed!")
    error = True

if domain is None:
    print("No domain (-d) passed!")
    error = True

if sender is None:
    print("No sender (-s) passed!")
    error = True

if code is None:
    print("No RFC4408-compliant validation response (-r) passed!")
    error = True

if error:
    sys.stderr.write("Exiting because of errors...\n")
    exit(1)

try:
    results = spf.check2(i=ip,s=sender,h=domain,timeout=float(timeout))
except:
    print "Exception ocurred when trying to check SPF record: ", sys.exc_info()
    exit(EXIT_UNKNOWN)


real_code = results[0]
msg = results[1]

detail = Template(detail_template).substitute(ip=ip,sender=sender,domain=domain,code=real_code)
if code == real_code:
    print "CHECK_SPF OK:",detail
    exit(EXIT_OK)
elif warning_mode:
    print "CHECK_SPF WARNING:",detail
    exit(EXIT_WARNING)
else:
    print "CHECK_SPF CRITICAL:",detail
    exit(EXIT_CRITICAL)

