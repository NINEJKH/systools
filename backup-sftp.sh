#!/usr/bin/env bash
#
# create simple rsync-style backups over sftp
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

required_vars=(
  SOURCE_SFTP_HOST
  SOURCE_SFTP_USER
  SOURCE_SFTP_PATH
  TARGET_PATH
)
for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var}" ]]; then
    echo "required var missing (${required_var})" 1>&2
    exit 2
  fi
done

if [[ -z "${SOURCE_SFTP_PORT}" ]]; then
  SOURCE_SFTP_PORT="22"
fi

mkdir -p "${TARGET_PATH}"

# "rsync" via sftp
lftp -c "
open -p ${SOURCE_SFTP_PORT} -u ${SOURCE_SFTP_USER},placeholder sftp://${SOURCE_SFTP_HOST}
mirror ${MIRROR_EXTRA_ARGS} --only-newer --delete --parallel=${MIRROR_PARALLEL:-8} ${SOURCE_SFTP_PATH} ${TARGET_PATH}
" > /dev/null

# create tar file
tar cf "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar" -C "${TARGET_PATH}" .
pigz "${BASE_FOLDER}${TARGET_FILENAME:-bak}.tar"
