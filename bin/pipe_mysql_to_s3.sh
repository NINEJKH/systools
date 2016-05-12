#!/bin/bash
#
# Author: Gunter Grodotzki (gunter@grodotzki.co.za)
# Version: 2015-11-20
#
# Pipe MySQL dumps to S3.

set -e

__DIR__="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# required libs
source "${__DIR__}/shlib/variables.shlib"


# check if required vars were set
if ! variables::isset MYSQL_HOST MYSQL_USER MYSQL_PASS MYSQL_DB AWS_PROFILE S3_BUCKET FILE_PREFIX NUM_BACKUPS; then
  echo 'Please make sure that the following envvars are set:' 1>&2
  echo '' 1>&2
  echo 'MYSQL_HOST' 1>&2
  echo 'MYSQL_USER' 1>&2
  echo 'MYSQL_PASS' 1>&2
  echo 'MYSQL_DB' 1>&2
  echo 'AWS_PROFILE' 1>&2
  echo 'S3_BUCKET' 1>&2
  echo 'FILE_PREFIX' 1>&2
  echo 'NUM_BACKUPS' 1>&2
  exit 1
fi

#
# create new backup
#

filename="${FILE_PREFIX}-$(date +%Y-%m-%d).zip"

mysqldump \
--compress \
--single-transaction \
--quick \
-h"${MYSQL_HOST}" \
-u"${MYSQL_USER}" \
-p"${MYSQL_PASS}" \
"${MYSQL_DB}" > dump.sql

zip "${filename}" dump.sql

rm dump.sql

aws \
--profile "${AWS_PROFILE}" \
--output text \
s3 cp "${filename}" "s3://${S3_BUCKET}"

rm "${filename}"


#
# purge older backups
#

# get a list of all files (this might get extremly slow on larger lists?)
aws --profile "${AWS_PROFILE}" --output text s3 ls "s3://${S3_BUCKET}" |
# we are only interested in our backps
grep "${FILE_PREFIX}" |
# squash repeating spaces
tr -s ' ' |
# sort by (and only by) the 1st column DESC
sort -k1,1r |
# loop through the results
while read -r each_date each_time each_size each_file; do
  n=$((n + 1))

  # delete older snapshots after the desired amount is reached
  if [ "${n}" -gt "${NUM_BACKUPS}" ]; then
    echo "[Deleting] ${each_file} - ${each_date}"
    aws --profile "${AWS_PROFILE}" --output text s3 rm "s3://${S3_BUCKET}/${each_file}"
  fi
done

exit 0