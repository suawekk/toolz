#!/bin/bash
################################################################################
# LVM snapshot removal tool
# Intended to help doing cleanup after backup interrupted by reboot
################################################################################
set -e

PATH="/usr/bin:/bin:/sbin:/usr/sbin"
SEPARATOR=':'

# First flag in 'lv_attr' field can reveal whether volume is a snapshot
# Open flag is sixth attribute of lv_attr field
# We don't want to list open snapshots - automatically closing them may result 
#in some data loss and this script is intended for automatic and 
#non-interactive use
SNAPSHOT_FLAG_RE="/^s.{4}[^o]/"

if [[ $EUID != 0 ]]
then
    echo "This program is intended to be running as root! Exiting..." >&2
    exit 1
fi


LVS=$(which lvs 2>/dev/null || { echo "No lvs binary found. is lvm2 or equivalent package installed?" >&2; exit 1; })
LVREMOVE=$(which lvremove 2>/dev/null || { echo "No lvs binary found. is lvm2 or equivalent package installed?" >&2; exit 1; })

AWK=$(which awk 2>/dev/null || { echo "No awk binary found. is your system broken or what?" >&2; exit 1; })

#Get snapshot list 
SNAPSHOTS=$($LVS --separator "$SEPARATOR" --noheadings -olv_path,lv_attr | awk -F"$SEPARATOR" "\$2 ~ $SNAPSHOT_FLAG_RE { printf(\"%s \",\$1); }")

if [[ $? != 0 ]]
then
    echo "Failed to get snapshot list from $LVS output" >&2
    exit 1
fi

ERROR=0

if [[ -z "$SNAPSHOTS" ]]
then
    echo "No snapshots suitable for removal ( = non-open snapshots) found. exiting..."
    exit 0
fi

echo "removing snapshots: $SNAPSHOTS"
CMD="$LVREMOVE -A y -f -y -q $SNAPSHOTS"
echo "calling \"$CMD\""

$CMD

if [[ $? == 0 ]]
then
    echo "Snapshots: $SNAPSHOTS removed."
else
    echo "Snapshots: $SNAPHOSTS not removed." >&2
    ERROR=1
fi

exit $ERROR
