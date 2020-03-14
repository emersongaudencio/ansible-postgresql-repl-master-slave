#!/bin/bash

export SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PYTHON_BIN=/usr/bin/python
export ANSIBLE_CONFIG=$SCRIPT_PATH/ansible.cfg

cd $SCRIPT_PATH

VAR_HOST="$1"
VAR_POSTGRESQL_VERSION="$2"
VAR_SERVERID="$3"
VAR_PRIMARY_SERVER="$4"

if [ "${VAR_HOST}" == '' ] ; then
  echo "No host specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_POSTGRESQL_VERSION}" == '' ] ; then
  echo "No PostgreSQL version specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_SERVERID}" == '' ] ; then
  echo "No SERVERID domain specified. Please have a look at README file for futher information!"
  exit 1
fi

if [ "${VAR_PRIMARY_SERVER}" == '' ] ; then
  echo "No Primary Server specified. Please have a look at README file for futher information!"
  exit 1
fi

### Ping host ####
ansible -i $SCRIPT_PATH/hosts -m ping $VAR_HOST -v

### MariaDB install ####
ansible-playbook -v -i $SCRIPT_PATH/hosts -e "{postgresql_version: '$VAR_POSTGRESQL_VERSION', serverid: '$VAR_SERVERID', primary_server: '$VAR_PRIMARY_SERVER'}" $SCRIPT_PATH/playbook/postgres_master_slave.yml -l $VAR_HOST
