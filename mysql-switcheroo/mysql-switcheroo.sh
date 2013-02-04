#/bin/bash -x 
#
#
# Password file format:
# host1:user_1:pw_1
# host1:user_2:pw_1


################################################################################
# constant definitions
################################################################################
PW_FILE='passwd.txt'
PW_FIELD_SEPARATOR=':'

#passwd file field indices
PW_HOST_FIELD_INDEX=1
PW_USER_FIELD_INDEX=2
PW_PASS_FIELD_INDEX=3

ACTIVE_USER=
ACTIVE_PW=
STANDBY_USER=
STANDBY_PW=

#how long wait between checking replication lag
REPL_CATCHUP_SLEEP=0.3

#how many times try to check replication status.
REPL_CATCHUP_TRIES=200

ACTIVE=
STANDBY=
COMMANDS=(mysql mysqladmin grep awk expr sleep)

################################################################################
# function definitions
################################################################################
function get_field {
    #parameter checks
    if [[ -z $1 ]]
    then
        echo "No host passed"
        return -1
    elif [[ -z $3 ]]
    then
        echo "No field number passed"
        return -1
    elif [[ -z $2 ]]
    then
        echo "No output variable passed"
        return -1
    fi

    local HOST=$1
    local FIELD_IND=$3
    local OUT_VAR=$2

    local VAL=`$GREP $HOST $PW_FILE | $AWK -F"$PW_FIELD_SEPARATOR" "{print \\\$${FIELD_IND} }"`
    eval "$OUT_VAR=\"$VAL"\"
}

function get_user {
    get_field $1 $2 2
}

function get_pw {
    get_field $1 $2 3
}

function mysql_cmd(){
    local HOST=$1
    local USER=$2
    local PW=$3
    local CMD=$4
    local RESULT_VAR=$5
    local VAL=`mysql -sB -h $HOST -p$PW -u $USER -e "$CMD" 2>/dev/null`
    eval "$RESULT_VAR=\"$VAL\""
}


function check_slave {
    HOST=$1
    USER=$2
    PW=$3

    local OUT
    mysql_cmd $HOST $USER $PW "show slave status\G;" OUT

    for expr in 'Slave_IO_Running:\s+Yes' 'Slave_SQL_Running:\s+Yes'
    do
        echo $OUT | $GREP -Pq $expr

        if [[  $? -ne 0 ]]
        then
            return 0
        fi
    done
    return 1
}

function slave_lag_wait {
    HOST=$1
    USER=$2
    PW=$3
    SLEEP_TIME=$4
    TRIES=$5
    
    local i=0;


    echo -n '.'
    mysql_cmd $HOST $USER $PW "show slave status\G;" OUT
    echo $OUT | $GREP -Pq 'Seconds_Behind_Master:\s+0'

    while [[ $? -ne 0 && $i -lt $TRIES ]]
    do
        i=`$EXPR $i + 1`
        echo -n '.'
        mysql_cmd $HOST $USER $PW "show slave status\G;" OUT
        echo $OUT | $GREP -Pq 'Seconds_Behind_Master:\s+0'
        $SLEEP $SLEEP_TIME
    done

    if [[ $i -eq $TRIES ]]
    then
        return 0
    fi

    return 1
}

################################################################################
# actual script execution starts below
################################################################################

#check for external commands existence
typeset -u cmd_upper
for command in ${COMMANDS[@]}
do
    cmd_upper=$command
    cmd_path=`which $command 2>/dev/null`

    if [[ -z "$cmd_path" ]]
    then
        echo "No '$command' tool found!"
        exit 1
    fi
    eval "${cmd_upper}=$cmd_path"
done
unset cmd_upper

while getopts :a:s: OPT
do
    case $OPT in
        a)
            ACTIVE=$OPTARG
        ;;
        s)
            STANDBY=$OPTARG
        ;;
        f)
            PW_FILE=$OPTARG
        ;;
    esac
done

if [[ ! -f "$PW_FILE" ]]
then
    echo "$PW_FILE is unreadable/nonexisting!"
fi

get_user $ACTIVE ACTIVE_USER
get_user $STANDBY STANDBY_USER
get_pw $ACTIVE ACTIVE_PW
get_pw $STANDBY STANDBY_PW

check_slave $ACTIVE $ACTIVE_USER $ACTIVE_PW
if [[  $? -ne 1 ]]
then
    echo "host: $ACTIVE has broken replication, exiting."
    exit -10;
fi

check_slave $STANDBY $STANDBY_USER $STANDBY_PW
if [[ $? -ne 1 ]]
then
    echo "host: $STANDBY has broken replication, exiting."
    exit -10;
fi

echo "Setting host: $STANDBY as standby:"

#lock access to new secondary.
mysql_cmd  $STANDBY $STANDBY_USER $STANDBY_PW "set global read_only=ON;show variables like 'read_only'" OUT
echo "$OUT" | $GREP -qP 'read_only\s+ON'

if [[ $? -eq 0 ]]
then
    echo "$STANDBY changed to read only mode"
else
    echo "Failed to set $STANDBY to read only mode"
    exit -1
fi 

echo "Waiting for replication at $ACTIVE to catch up..."
slave_lag_wait $ACTIVE $ACTIVE_USER $ACTIVE_PW $REPL_CATCHUP_SLEEP $REPL_CATCHUP_TRIES

echo "Setting host: $ACTIVE as active:"

#unlock access to new primary
mysql_cmd $ACTIVE $ACTIVE_USER $ACTIVE_PW "set global read_only=OFF;show variables like 'read_only'" OUT

echo "$OUT" | $GREP -qP 'read_only\s+OFF'

if [[ $? -eq 0 ]]
then
    echo "$ACTIVE changed to read/write"
else
    echo "Failed to set $ACTIVE to read/write mode"
    echo "Recovery: setting host: $STANDBY as active:"

    #revert old access  to desired standby
    mysql_cmd  $STANDBY $STANDBY_USER $STANDBY_PW "set global read_only=OFF;show variables like 'read_only'" OUT
    echo "$OUT" | $GREP -qP 'read_only\s+OFF'

    if [[ $? -eq 0 ]]
    then
        echo "$STANDBY restored to read/write mode"
        exit -2
    else
        echo "Failed to reset $STANDBY to read/write mode. This is bad! Fix manually ASAP"
        exit -3
    fi 
fi 

