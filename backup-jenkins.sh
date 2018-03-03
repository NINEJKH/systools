#!/usr/bin/env bash
#
# backup jenkins and push to s3
#

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$("${readlink_bin}" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

source "${__DIR__}/libs/functions.shlib"

set -E
trap 'throw_exception' ERR

# create tar file
tar cf "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar" -C "${JENKINS_HOME:-/var/lib/jenkins}" .
pigz "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar"

target_filename="${FILE_PREFIX}$(date +%Y-%m-%d).tar.gz"

# push to s3
aws \
  --profile "${AWS_PROFILE}" \
  s3 cp \
  "bak.tar.gz" "s3://${S3_BUCKET}/${S3_PREFIX}${target_filename}"
  --quiet

rm -f "bak.tar.gz"
