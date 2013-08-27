#!/bin/bash
IPTABLES=$(which iptables) 
SUDO=$(which sudo)
SSH=$(which ssh)
SED=$(which sed)
AWK=$(which awk)

CHAIN=
COMMENT=
ERROR=0
NO_DNS=0
REMOTE_HOST=
TABLE=filter
TARGET=
USE_SUDO=0
VERBOSE=0
SSH_ARGS="-24tv"
SEP="--------------------"


help(){
    echo "Iptables rule replacer by suawek <suawekk@gmail.com>"
    echo 
    echo "Searches for rule with comment COMMENT and replaces its target to string passed as TARGET_SPEC"
    echo
    echo "args:" 
    echo "-C                => comment to search for"
    echo "-c CHAIN          => chain"
    echo "-j TARGET_SPEC    =>  target specification"
    echo "-n                => dont resolve domains when calling iptables ( adds -n to cmdline)" 
    echo "-r REMOTE_HOST    => will call iptables  by ssh to REMOTE_HOST, calls iptables on localhost if not set (without ssh)"
    echo "-s                => use sudo when calling iptables (works also on remotes)"
    echo "-t                => table"
    echo
    echo "Prerequisites: "
    echo "iptables"
    echo "sudo (when using sudo)"
    echo "ssh (when using ssh)"
    echo "sed (for text manipulation)"
    echo "awk (for text manipulation)"
}

error(){
    ERROR=1
    echo -e "[1;31m$1[1;0m" >&2
}

while getopts :c:C:t:j:r:hns  OPT
do
    case $OPT in
        h)
            help
            exit 0
        ;;
        r)
            REMOTE_HOST=$OPTARG
        ;;
        s)
            USE_SUDO=1
        ;;
        n)
            NO_DNS=1
        ;;
        c)
            CHAIN=$OPTARG
        ;;
        C)
            COMMENT=$OPTARG
        ;;

        t)
            TABLE=$OPTARG
        ;;

        j)
            TARGET_SPEC=$OPTARG
        ;;

        \?)

        ;;
    esac
done


if [[ -z $TABLE ]]
then
    error "No table supplied (-t)"
    exit 1
elif [[ -z "$CHAIN" ]]
then
    error "No chain supplied (-c)"
    exit 2
elif [[ -z "$COMMENT" ]]
then
    error "No comment supplied (-C)"
    exit 3
elif [[ -z "$TARGET_SPEC" ]]
then
    error "No new rule target supplied (-j)"
    exit 4
fi

if [[ $NO_DNS == 1 ]]
then
    DNS_SPEC="-n"
fi

if [[ "$USE_SUDO" == "1" ]]
then
    IPT_CMD="$SUDO $IPTABLES"
else
    IPT_CMD="$IPTABLES"
fi

if [[ -n "$REMOTE_HOST" ]]
then
    IPT_CMD="$SSH $SSH_ARGS $REMOTE_HOST $IPT_CMD"
fi

RULE_INDEX=$($IPT_CMD --line-numbers -t $TABLE $DNS_SPEC -vL $CHAIN | $AWK "/\/\* $COMMENT \*\// {print \$1; exit}")

if [[ -z $RULE_INDEX ]]
then
    error "Rule containing comment: '$COMMENT' was not found! (chain: $CHAIN, table: $TABLE)"
    exit 1
else
    echo "Found rule with comment: '$COMMENT' at index $RULE_INDEX (chain: $CHAIN, table: $TABLE)"
fi

RULE=$($IPT_CMD -t $TABLE -S $CHAIN | $AWK "/--comment\s+$COMMENT\s+/ {print ; exit}")
RULE_NOPREFIX=$(echo "$RULE" | $SED -e "s/^-A $CHAIN //")
RULE_BARE=$(echo "$RULE_NOPREFIX" | $SED -e 's/-j.*$//')

TARGET_RULE="$RULE_BARE -j $TARGET_SPEC"
echo -e "Replacing rule:\n[1;31m$RULE_NOPREFIX[1;0m\nwith:\n[1;32m$TARGET_RULE[1;0m"

REPLACE_CMD="$IPT_CMD -t $TABLE -R $CHAIN $RULE_INDEX $TARGET_RULE"

echo
echo "Calling '$REPLACE_CMD'"
echo

eval $REPLACE_CMD



LIST_CMD="$IPT_CMD $DNS_SPEC --line-numbers -t $TABLE -vL  $CHAIN"
echo "Target chain now looks like this:"
echo -ne "$SEP\n\[1;34m$($LIST_CMD)[1;0m\n$SEP\n"


if [[ $? -ne 0  ]]
then
    error "Failed! dont\' know what to do. Inspect iptables manually!"
    exit 1
else
    echo "All done!"
fi
