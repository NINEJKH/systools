#!/usr/bin/env bash

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

# required libs
source "${__DIR__}/libs/functions.lib.sh"

set -E
trap 'throw_exception' ERR

while IFS= read -r -d '' -u 9; do
  if grep -q "${1}" "${REPLY}"; then
    consolelog "found match: ${REPLY}"
    sed -i.bak "s/${1}/${2}/g" "${REPLY}"
    rm -f "${REPLY}.bak"
  fi
done 9< <( find . -type f -name config.xml -exec printf '%s\0' {} + )
