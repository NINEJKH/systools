#!/usr/bin/env bash
#
# create simple rsync backups over ssh
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

required_vars=(
  SOURCE_SSH_HOST
  SOURCE_SSH_USER
  SOURCE_SSH_PATH
  TARGET_PATH
)
for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var}" ]]; then
    echo "required var missing (${required_var})" 1>&2
    exit 2
  fi
done

extra_args=()
ssh_args=()

if [[ -z "${SOURCE_SSH_PORT}" ]]; then
  SOURCE_SSH_PORT="22"
fi

if [[ ! -z "${RSYNC_SUDO}" ]]; then
  extra_args+=( --rsync-path="sudo rsync" )
fi

ssh_args+=( "-p" )
ssh_args+=( "${SOURCE_SSH_PORT}" )

if [[ ! -z "${SOURCE_SSH_KEYFILE}" ]]; then
  ssh_args+=( "-i" )
  ssh_args+=( "${SOURCE_SSH_KEYFILE}" )
fi

mkdir -p "${TARGET_PATH}"

rsync \
  -azq \
  --delete \
  "${extra_args[@]}" \
  -e 'ssh '"${ssh_args[@]}"'' \
  "${SOURCE_SSH_USER}@${SOURCE_SSH_HOST}:${SOURCE_SSH_PATH}" "${TARGET_PATH}"

# create tar file
tar cf "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar" -C "${TARGET_PATH}" .
pigz "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar"
