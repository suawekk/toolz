#!/bin/bash

REPOS_ROOT=/home/svnbackup/repos
BACKUP_ROOT=/home/svnbackup/backups
NUM_BACKUPS=60
HOT_BACKUP_SCRIPT=~/bin/hot-backup.py
HOT_BACKUP_SCRIPT_ARGS="--archive-type=bz2 --num-backups=$NUM_BACKUPS --verify"
SVNSYNC=$(which svnsync 2>/dev/null)
REPOS=(repo1 repo2)

echo "test" >&2
for REPO in ${REPOS[@]}
do
        REPO_DIR="$REPOS_ROOT/$REPO"

        if [[ ! -d "$REPO_DIR" ]]
        then
                echo "$REPO_DIR does not exist or is not a directory!" >&2
                exit 1
        fi

        echo "Replicating repository $REPO.."
        $SVNSYNC synchronize file://$REPO_DIR

        if [[ $? -ne 0 ]]
        then
                echo "Failed to replicate repository, skipping backup..." >&2
                exit 2
        fi

        echo "Backing up local repository copy..."

        BACKUP_DIR="$BACKUP_ROOT/$REPO"
        $HOT_BACKUP_SCRIPT $HOT_BACKUP_SCRIPT_ARGS $REPO_DIR $BACKUP_DIR

        if [[ $? -eq 0 ]]
        then
                echo "Backup completed successfully!"
        else
                echo "Failed to backup repository!" >&2
        fi
done
