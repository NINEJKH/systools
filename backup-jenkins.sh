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

if [[ -z "${TARGET_FILENAME}" ]]; then
  TARGET_FILENAME="${FILE_PREFIX}$(date +%Y-%m-%d)"
fi

# cleanup
rm -f "${BASE_FOLDER}${TARGET_FILENAME}.tar"
rm -f "${BASE_FOLDER}${TARGET_FILENAME}.tar.gz"

# create tar file
tar cf "${BASE_FOLDER}${TARGET_FILENAME}.tar" -C "${JENKINS_HOME:-/var/lib/jenkins}" .
pigz "${BASE_FOLDER}${TARGET_FILENAME}.tar"

# push to s3
aws \
  --profile "${AWS_PROFILE}" \
  s3 cp \
  "${BASE_FOLDER}${TARGET_FILENAME}.tar.gz" "s3://${S3_BUCKET}/${S3_PREFIX}${TARGET_FILENAME}.tar.gz" \
  --quiet

# cleanup
rm -f "${BASE_FOLDER}${TARGET_FILENAME}.tar.gz"
