#!/bin/sh
# Julius Zaromskis
# Backup and Backup rotation script
# Amended by Henry Standing 26 Feb 2018

# Storage folder where to move backup files
# Must contain backup.monthly backup.weekly backup.daily folders
BACKUP_DIR=/home/backups/deadbirdalley
FILES_DIR=/var/www/owncloud
CONFIG_DIR=/etc
ROOT_DIR=/root
DATA_DIR=/home/ocdata
# Source folder where files are backed
SOURCE_DIR=$BACKUP_DIR/incoming

# Dump MySQL tables
mysqldump -h 127.0.0.1 -u admin -pV^WzrU%VDc6mAASq585RmOz^ owncloud > $BACKUP_DIR/incoming/mysql_dump.sql

# Compress tables and files
tar -cvzf $BACKUP_DIR/incoming/archive.tgz $BACKUP_DIR/incoming/mysql_dump.sql $FILES_DIR $CONFIG_DIR $ROOT_DIR $DATA_DIR

# Cleanup
rm $BACKUP_DIR/incoming/mysql_dump.sql

# Run backup rotate
cd $BACKUP_DIR


# Destination file names
DATE_DAILY=`date +"%d-%m-%Y"`
#date_weekly=`date +"%V sav. %m-%Y"`
#date_monthly=`date +"%m-%Y"`

# Get current month and week day number
MONTH_DAY=`date +"%d"`
WEEK_DAY=`date +"%u"`

# Optional check if source files exist. Email if failed.
if [ ! -f $SOURCE_DIR/archive.tgz ]; then
ls -l $SOURCE_DIR/ | mail henry.standing@gmail.com -s "[DeadBirdAlley] Daily backup failed! Please check for missing files." < /dev/null
fi

# It is logical to run this script daily. We take files from source folder and move them to
# appropriate destination folder

# On first month day do
if [ "$MONTH_DAY" -eq 1 ] ; then
  DESTINATION=backup.monthly/$DATE_DAILY
else
  # On saturdays do
  if [ "$WEEK_DAY" -eq 6 ] ; then
    DESTINATION=backup.weekly/$DATE_DAILY
  else
    # On any regular day do
    DESTINATION=backup.daily/$DATE_DAILY
  fi
fi

# Move the files
mkdir $DESTINATION
mv -v $SOURCE_DIR/* $DESTINATION

# daily - keep for 14 days
find $BACKUP_DIR/backup.daily/ -maxdepth 1 -mtime +14 -type d -exec rm -rv {} \;

# weekly - keep for 60 days
find $BACKUP_DIR/backup.weekly/ -maxdepth 1 -mtime +60 -type d -exec rm -rv {} \;

# monthly - keep for 300 days
find $BACKUP_DIR/backup.monthly/ -maxdepth 1 -mtime +300 -type d -exec rm -rv {} \;

# Sync backup folder to Amazon S3 bucket

aws s3 sync $BACKUP_DIR s3://dba-backup-bucket/backups
