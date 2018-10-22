#!/usr/bin/env bash
#
# backup jenkins and push to s3
#

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

source "${__DIR__}/libs/functions.lib.sh"

set -E
trap 'throw_exception' ERR

if [[ -z "${TARGET_FILENAME}" ]]; then
  TARGET_FILENAME="${FILE_PREFIX}$(date +%d-%m-%Y_%H-%M)"
fi

# cleanup
rm -f "${BASE_FOLDER}${TARGET_FILENAME}.zip"

# tar fails when files change during the process (which unfortunately happens a lot with jenkins) - so lets use zip instead which seems to be less problematic
( cd "${JENKINS_HOME:-/var/lib/jenkins}" && zip \
  --quiet \
  --symlinks \
  --recurse-paths \
  - . \
  --exclude "cache/*" "nodes/*" "workspace/*" "logs/*" "org.jenkinsci.plugins.github.GitHubPlugin.cache/*" \
) > "${BASE_FOLDER}${TARGET_FILENAME}.zip"

extra_global_args=()
extra_args=()

if [[ ! -z "${AWS_PROFILE}" ]]; then
  extra_global_args+=( "--profile" )
  extra_global_args+=( "${AWS_PROFILE}" )
fi

if [[ ! -z "${S3_KMS_KEY}" ]]; then
  extra_args+=( "--sse" )
  extra_args+=( "aws:kms" )
  extra_args+=( "--sse-kms-key-id" )
  extra_args+=( "${S3_KMS_KEY}" )
fi

# push to s3
if ! aws \
  "${extra_global_args[@]}" \
  s3 cp \
  "${BASE_FOLDER}${TARGET_FILENAME}.zip" "s3://${S3_BUCKET}/${S3_PREFIX}${TARGET_FILENAME}.zip" \
  --only-show-errors \
  "${extra_args[@]}"; then

  consolelog "s3 upload failed" "error"
  rm -f "${BASE_FOLDER}${TARGET_FILENAME}.zip"
  exit 1
else
  rm -f "${BASE_FOLDER}${TARGET_FILENAME}.zip"
fi
