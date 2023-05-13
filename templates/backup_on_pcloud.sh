#!/bin/sh

# Local variable used by this script
LOG_FILE=/logs/Photos_on_pcloud.log
SOURCE_FOLDER=/nas_data/photo/Photos
REMOTE=pCloud
TARGET_FOLDER=Backups/Photos

echo "$(date +"%Y/%m/%d %T") Starting to sync on $REMOTE (from $SOURCE_FOLDER to $TARGET_FOLDER, logs in $LOG_FILE)..."
echo "$(date +"%Y/%m/%d %T") Starting to sync on $REMOTE (from $SOURCE_FOLDER to $TARGET_FOLDER)..." >> $LOG_FILE

# -v option shows the progress on the console every minute, check the docker console for updates.
rclone sync --log-file=$LOG_FILE $SOURCE_FOLDER $REMOTE:$TARGET_FOLDER --exclude-from /config/rclone/exclude-list.txt --delete-excluded -v

echo "$(date +"%Y/%m/%d %T") ...Finished sync on $REMOTE."
echo "$(date +"%Y/%m/%d %T") ...Finished sync on $REMOTE." >> $LOG_FILE

exit