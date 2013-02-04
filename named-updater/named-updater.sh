
#!/bin/bash
################################################################################
# NSUPDATE wrapper script
# author: Sławomir Kowalski <suawekk@gmail.com>
# version: 0.1
# date: 14-01-2012
################################################################################

################################################################################
# Variables
################################################################################

KEYFILE=
RECORD=
ADDR=
TYPE=A
TTL=86400
HOST=localhost
NSUPDATE=`which nsupdate 2>/dev/null`
RNDC=/usr/sbin/rndc
SUDO=`which sudo 2>/dev/null`
NSUPDATEARGS='-v'

################################################################################
# Scripts starts below
################################################################################

while getopts :a:f:k:r:t OPT
do
    case $OPT in
        k)
            KEYFILE=$OPTARG
        ;;
        r)
            RECORD=$OPTARG
        ;;
        a)
            ADDR=$OPTARG
        ;;
        t)
            TTL=$OPTARG
        ;;
        h)
            HOST=$OPTARG
        ;;
    esac
done

if [[ -z "$NSUPDATE" ]]
then
    echo "no 'nsupdate' in PATH=$PATH"
fi

if [[ -z "$NSUPDATE" ]]
then
    echo "no 'nsupdate' in PATH=$PATH"
fi

while getopts :a:f:k:r:t OPT
do
    case $OPT in
        k)
            KEYFILE=$OPTARG
        ;;
        r)
            RECORD=$OPTARG
        ;;
        a)
            ADDR=$OPTARG
        ;;
        t)
        ;;
            TTL=$OPTARG
        h)
            HOST=$OPTARG
        ;;
    esac
done

if [[ ! -f $KEYFILE ]]
then
    echo "File: '$KEYFILE' does not exist or is not readable!"
fi


echo "Updating DNS record: $RECORD to point to $ADDR, server is: $HOST"

cat <<DONE | $NSUPDATE -k $KEYFILE $NSUPDATEARGS
server $HOST
update delete ${RECORD}.
update add ${RECORD}. $TTL $TYPE $ADDR
send
quit
DONE

#extract zone name from RR
ZONE=${RECORD#*\.}
echo "Freezing zone $ZONE"
$SUDO $RNDC freeze $ZONE
echo "Unfreezing zone $ZONE"
$SUDO $RNDC unfreeze $ZONE
