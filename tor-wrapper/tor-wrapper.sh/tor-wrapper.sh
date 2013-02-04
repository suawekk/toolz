#!/bin/bash

HOST=127.0.0.1
CONTROL_PORT=9051
CONTROL_PASS=
CMD=$@

#request new TOR identity
echo -ne "AUTHENTICATE \"$CONTROL_PASS\"\r\nSIGNAL NEWNYM\r\n" | netcat $HOST $CONTROL_PORT &>/dev/null
torify $CMD
