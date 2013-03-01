#!/bin/bash
################################################################################
# Cookie check for KK
# author: suawekk <suawekk@gmail.com>
# date: 01-03-2013 
#
# Requirements (should be in $PATH):
#  -grep
#  -curl
#  -gawk
#  -date
#
# What does it do?
# It tries to fetch a website passed as $1 and performs check on cookie passed
# as $2 . Cookie values are saved by curl to temp location on first request 
# or when expired.
# If cookie file is nonexistent script assumes OK
# If file exists:
#  -If cookie is saved in temp file (and still valid) and server has set new cookie 
#  check throws error (server set new cookie and discarded still valid cookie)
#  otherwise script returns OK
#
################################################################################

GREP=$(which grep) 
CURL=$(which curl)
AWK=$(which gawk)
DATE=$(which date)

if [[ -z $1 ]]
then
    echo "No website passed!" 1>&2
    exit 3
elif [[ -z $2 ]]
then
    echo "No cookie name passed!" 1>&2
    exit 3
fi

WEBSITE=$1
COOKIE_NAME=$2
COOKIE_STORE_PREFIX=/tmp/cookie_check_
COOKIE_STORE=${COOKIE_STORE_PREFIX}${WEBSITE}-${COOKIE_NAME}
CMD="curl -I $WEBSITE -c $COOKIE_STORE -b $COOKIE_STORE"

if [[ ! -f $COOKIE_STORE ]]
then
    echo "First request - assuming OK"
    $CMD &>/dev/null
    exit 0
else
    VALIDITY=$($GREP $COOKIE_NAME $COOKIE_STORE | $AWK '{print $5}')
    NOW=$($DATE '+%s')

    if (( $NOW >= $VALIDITY))
    then
        echo "Cookie expired, re-requesting and assuming OK"
        $CMD &>/dev/null
        exit 0
    fi

    GREPPED=$($CMD | $GREP -P Set-Cookie:\s+$COOKIE_NAME)
    if [[ -z $GREPPED ]]
    then
        echo "Check OK!"
        exit 0
    else
        echo "Check failed!" 
        exit 2
    fi
fi
