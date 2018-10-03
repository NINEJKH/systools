#!/bin/bash

set -e

for t in $(mysql --batch --skip-column-names -e 'show tables' "${1}"); do
  echo "converting ${1}.${t}"
  mysql -e "ALTER TABLE \`${t}\` ENGINE = InnoDB;" "${1}"
done
