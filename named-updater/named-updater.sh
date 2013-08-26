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
SUDO=""
NSUPDATEARGS='-v'
RNDCKEY=""
PORT=953

################################################################################
# Scripts starts below
################################################################################

while getopts ":a:f:k:r:t:h:z:K:V:p:m:" OPT
do
    case $OPT in
        k)
            KEYFILE="$OPTARG"
        ;;
        K)
            RNDCKEY="$OPTARG"
        ;;
        r)
            RECORD=$OPTARG
        ;;
        m)
            MASS_UPDATE_FILE=$OPTARG
        ;;
        a)
            ADDR=$OPTARG
        ;;
        p)
            PORT=$OPTARG
        ;;
        t)
            TTL=$OPTARG
        ;;
        h)
            HOST=$OPTARG
        ;;
        z)
            ZONE=$OPTARG
        ;;
        V)
            VIEW="$OPTARG"
        ;;
    esac
done

if [[ -z "$NSUPDATE" ]]
then
    echo "no 'nsupdate' in PATH=$PATH"
    exit 1
fi

if [[ -z "$NSUPDATE" ]]
then
    echo "no 'nsupdate' in PATH=$PATH"
    exit 1
fi

if [[ ! -f "$KEYFILE" ]]
then
    echo "File: '$KEYFILE' does not exist or is not readable!"
    exit 1
fi

if [[ ! -f "$RNDCKEY" ]]
then
    echo "File: 'RNDCKEY' does not exist or is not readable!"
    exit 1
fi



if [[ -z "$MASS_UPDATE_FILE" ]]
then
	echo "Updating DNS record: $RECORD to point to $ADDR, server is: $HOST"
	UPDATE_STR="update delete ${RECORD}.|update add ${RECORD}. $TTL $TYPE $ADDR|"
else 
	echo "Procesing updates from file: $MASS_UPDATE_FILE"
	UPDATE_SPEC="$(cat $MASS_UPDATE_FILE)"

	UPDATE_STR=

	while read line
	do
		RECORD=$(echo "$line" | cut -d: -f1)
		ADDR=$(echo "$line" | cut -d: -f2)
		echo "Adding update: $RECORD = $ADDR ..."
		UPDATE_STR+="update delete ${RECORD}.|update add ${RECORD}. $TTL $TYPE $ADDR|"
	done < "$MASS_UPDATE_FILE"
fi

UPDATE_STR="$(echo "$UPDATE_STR" | tr '|' "\n")"

cat <<DONE | $NSUPDATE -k $KEYFILE $NSUPDATEARGS
server $HOST
$UPDATE_STR
send
quit
DONE

#extract zone name from RR
[[ -z "$ZONE" ]] && ZONE=${RECORD#*\.}


[[ -n "$VIEW" ]] && VIEW_SPEC="in $VIEW"
echo "Freezing zone $ZONE"
$SUDO $RNDC -k $RNDCKEY -s $HOST -p $PORT freeze $ZONE $VIEW_SPEC
echo "Unfreezing zone $ZONE"
$SUDO $RNDC -k $RNDCKEY -s $HOST -p $PORT unfreeze $ZONE $VIEW_SPEC
