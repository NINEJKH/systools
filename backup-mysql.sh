#!/usr/bin/env bash
#
# create simple mysql backups
#

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

source "${__DIR__}/libs/functions.shlib"

set -E
trap 'throw_exception' ERR

required_vars=(
  MYSQL_HOST
  MYSQL_USER
  MYSQL_PASS
  MYSQL_DB
)
for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var}" ]]; then
    echo "required var missing (${required_var})" 1>&2
    exit 2
  fi
done

if [[ -z "${MYSQL_PORT}" ]]; then
  MYSQL_PORT="3306"
fi

cat <<EOF > .my.cnf
[client]
host = ${MYSQL_HOST}
user = ${MYSQL_USER}
password = ${MYSQL_PASS}
port = ${MYSQL_PORT}
EOF

mysqldump --defaults-file=".my.cnf" \
  --compress \
  --single-transaction \
  --quick \
  "${MYSQL_DB}" > dump.sql

tar cf "${BASE_FOLDER}${TARGET_FILENAME:-dump}.tar" dump.sql
rm dump.sql
pigz "${BASE_FOLDER}${TARGET_FILENAME:-dump}.tar"
