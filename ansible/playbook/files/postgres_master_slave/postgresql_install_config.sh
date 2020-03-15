#!/bin/bash
# SERVERID is the ID related to the Master PG Server to help setup replication streaming on the replica servers.
SERVERID=$(cat /tmp/SERVERID)

### get total memory ram to configure maintenance_work_mem variable
MEM_TOTAL=$(expr $(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 10)) \* 10 / 1024 / 1024)

### get amount of memory who will be reserved to effective_cache_size variable
MEM_EFCS=$(expr $(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 10)) \* 7 / 1024)

### get amount of memory who will be reserved to shared_buffers variable
MEM_SHBM=$(expr $(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 10)) \* 2 / 1024)

### get the number of cpu's to estimate how many innodb instances will be enough for it. ###
NR_CPUS=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)

PG_VERSION=$(cat /tmp/PG_VERSION)

if [ "$PG_VERSION" -gt 9 -a "$PG_VERSION" -lt 13 ]; then
  DB_VERSION=`psql --version |awk {'print $3'}| awk -F "." {'print $1'}`
  pgsql_version=`psql --version |awk {'print $3'}| awk -F "." {'print $1'}`
  PARAM_PG_BKP="-P -v -w --xlog-method=stream"
elif [ "$PG_VERSION" -gt 93 -a "$PG_VERSION" -lt 97 ]; then
  DB_VERSION=`psql --version | egrep -o '[0-9]{1,}\.[0-9]{1,}'`
  pgsql_version=`psql --version |awk {'print $3'}| awk -F "." {'print $1$2'}`
  PARAM_PG_BKP="-P -v -w --wal-method=stream"
fi

if [ "$pgsql_version" == "94" ]; then
  PG_BLOCK="checkpoint_segments = 64"
else
  PG_BLOCK="min_wal_size = 2GB
max_wal_size = 4GB"
fi

if [ $MEM_TOTAL -lt 8 ]
  then
   MEM_MWM="512MB"
  elif [ $MEM_TOTAL -gt 8 ] && [ $MEM_TOTAL -lt 24 ]
  then
    MEM_MWM="1024MB"
  elif [ $MEM_TOTAL -gt 25 ]
  then
    MEM_MWM="2048MB"
fi

if [ $MEM_EFCS -gt 128 ]
  then
   MEM_EFCS="${MEM_EFCS}MB"
else
   MEM_EFCS="128MB"
fi

if [ $MEM_SHBM -gt 128 ]
  then
   MEM_SHBM="${MEM_SHBM}MB"
else
   MEM_SHBM="128MB"
fi

### postgres parms ###
MASTER_SERVER=$(cat /tmp/PRIMARY_SERVER)
LOCAL_SERVER_IP=" "

### check the ips address of the machines used on the cluster env ###
ips=($(hostname -I))
for ip in "${ips[@]}"
do
 if [ "$MASTER_SERVER" == "$ip" ];
 then
    LOCAL_SERVER_IP=$ip
    MASTER="OK"
    echo $LOCAL_SERVER_IP
 else
    if [ "$LOCAL_SERVER_IP" == " " ];
    then
    LOCAL_SERVER_IP=$ip
    MASTER="NO"
    echo $LOCAL_SERVER_IP
    fi
 fi
done

### remove old datadir ###
rm -rf /var/lib/pgsql

### datadir and logdir ####
DATA_DIR="/var/lib/pgsql/datadir"
DATA_LOG="/var/lib/pgsql/logdir"
ARCHIVE_LOG="/var/lib/pgsql/archivelog"

# create directories for mysql datadir and datalog
if [ ! -d ${DATA_DIR} ]
then
    mkdir -p ${DATA_DIR}
    chmod 755 ${DATA_DIR}
    chown -Rf postgres.postgres ${DATA_DIR}
fi

if [ ! -d ${DATA_LOG} ]
then
    mkdir -p ${DATA_LOG}
    chmod 755 ${DATA_LOG}
    chown -Rf postgres.postgres {DATA_LOG}
fi

if [ ! -d ${ARCHIVE_LOG} ]
then
    mkdir -p ${ARCHIVE_LOG}
    chmod 755 ${ARCHIVE_LOG}
    chown -Rf postgres.postgres {ARCHIVE_LOG}
fi

### initdb for deploy a new db fresh and clean ###
if [ "$PG_VERSION" -gt 9 -a "$PG_VERSION" -lt 13 ]; then
 /usr/pgsql-$DB_VERSION/bin/postgresql-$pgsql_version-setup initdb
elif [ "$PG_VERSION" -gt 93 -a "$PG_VERSION" -lt 97 ]; then
 /usr/pgsql-$DB_VERSION/bin/postgresql$pgsql_version-setup initdb
fi
systemctl enable postgresql-$DB_VERSION
systemctl start postgresql-$DB_VERSION
sleep 5

echo "

### include server.conf on postgresql.conf
include 'server.conf' " >> /var/lib/pgsql/$DB_VERSION/data/postgresql.conf

echo "
# DB Version: $DB_VERSION
# Server id = $SERVERID
# OS Type: linux
# DB Type: oltp
# Total Memory (RAM): $MEM_TOTAL GB
# CPUs num: $NR_CPUS
# Connections num: 500
# Data Storage: ssd

listen_addresses = '*'
max_connections = 500
shared_buffers = $MEM_SHBM
effective_cache_size = $MEM_EFCS
maintenance_work_mem = $MEM_MWM
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 16777kB
$PG_BLOCK

### enable archive mode ####
archive_mode = on
archive_command = 'cp %p $ARCHIVE_LOG/%f'
wal_level = 'hot_standby'
hot_standby = on
max_wal_senders = 6
wal_keep_segments = 10

### enable log file ###
log_directory = '$DATA_LOG'
log_filename = 'postgresql-%Y%m%d_%H%M%S.log'
log_rotation_age = 7d
log_rotation_size = 10MB
log_truncate_on_rotation = off
log_line_prefix = '%t c%  '

log_connections = on
log_disconnections = on
log_statement = 'ddl'
" > /var/lib/pgsql/$DB_VERSION/data/server.conf

echo "
# pg_hba.conf
host    all             all                0.0.0.0/0                md5
host    replication     replication_user   0.0.0.0/0                md5
" >> /var/lib/pgsql/$DB_VERSION/data/pg_hba.conf

# privs new files
chown -Rf postgres.postgres ${DATA_DIR}
chown -Rf postgres.postgres ${DATA_LOG}
chown -Rf postgres.postgres ${ARCHIVE_LOG}

if [[ $MASTER == "OK" ]]
then

# restart postgresql
systemctl stop postgresql-$DB_VERSION
sleep 5
systemctl start postgresql-$DB_VERSION; ec=$?
if [ $ec -ne 0 ]; then
     echo "Service startup failed - existing."
     exit 1
else
### generate root passwd #####
passwd="$SERVERID-PG"
touch /tmp/$passwd
echo $passwd > /tmp/$passwd
hash=`md5sum  /tmp/$passwd | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`

### update root password #####
sudo -u postgres psql -c "ALTER USER postgres WITH password '$hash'"

### standalone instance standard users ##
REPLICATION_USER_NAME="replication_user"

### generate replication passwd #####
RD_REPLICATION_USER_PWD="replication-$SERVERID"
touch /tmp/$RD_REPLICATION_USER_PWD
echo $RD_REPLICATION_USER_PWD > /tmp/$RD_REPLICATION_USER_PWD
HASH_REPLICATION_USER_PWD=`md5sum  /tmp/$RD_REPLICATION_USER_PWD | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`
REPLICATION_USER_PWD=$HASH_REPLICATION_USER_PWD

### setup the users for monitoring user/replication streaming ###
sudo -u postgres psql -c "CREATE USER $REPLICATION_USER_NAME REPLICATION LOGIN ENCRYPTED PASSWORD '$REPLICATION_USER_PWD'"

### show users and pwds ####
echo The server_id is $SERVERID!
echo The postgres password is $hash
echo The $REPLICATION_USER_NAME password is $REPLICATION_USER_PWD

touch /var/lib/pgsql/.psql_history
chown postgres: /var/lib/pgsql/.psql_history

### remove tmp files ###
rm -rf /tmp/*
fi

else

### standalone instance standard users ##
REPLICATION_USER_NAME="replication_user"

### generate replication passwd #####
RD_REPLICATION_USER_PWD="replication-$SERVERID"
touch /tmp/$RD_REPLICATION_USER_PWD
echo $RD_REPLICATION_USER_PWD > /tmp/$RD_REPLICATION_USER_PWD
HASH_REPLICATION_USER_PWD=`md5sum  /tmp/$RD_REPLICATION_USER_PWD | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`
REPLICATION_USER_PWD=$HASH_REPLICATION_USER_PWD


# restart postgresql
systemctl stop postgresql-$DB_VERSION
sleep 5

# cleaning datadir
cd /var/lib/pgsql/$DB_VERSION/
mv data old_data
mkdir data
chown postgres.postgres data
chmod 0700 data

# doing backup process
PGBKP_BIN=$(which pg_basebackup)
PGPASSWORD="$REPLICATION_USER_PWD" $PGBKP_BIN -h $MASTER_SERVER -U $REPLICATION_USER_NAME -D /var/lib/pgsql/$DB_VERSION/data $PARAM_PG_BKP

# changing permission on /var/lib/pgsql/$DB_VERSION/data
chown -Rf postgres.postgres /var/lib/pgsql/$DB_VERSION/data
cd /var/lib/pgsql/$DB_VERSION/data
chmod 0700 -Rf *
chmod 0600 *.conf
chmod 0600 PG_VERSION
chmod 0600 backup_label

echo "
standby_mode = 'on'
primary_conninfo = 'user=$REPLICATION_USER_NAME password=$REPLICATION_USER_PWD host=$MASTER_SERVER port=5432 sslmode=prefer'
recovery_target_timeline = 'latest'
" > /var/lib/pgsql/$DB_VERSION/data/recovery.conf
chown -Rf postgres.postgres /var/lib/pgsql/$DB_VERSION/data/recovery.conf
chmod 0600 /var/lib/pgsql/$DB_VERSION/data/recovery.conf
sleep 5

systemctl start postgresql-$DB_VERSION
sleep 5

touch /var/lib/pgsql/.psql_history
chown postgres: /var/lib/pgsql/.psql_history

### remove tmp files ###
rm -rf /tmp/*

fi
