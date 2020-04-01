#!/bin/sh
echo "HOSTNAME: " `hostname`
echo "BEGIN - [`date +%d/%m/%Y" "%H:%M:%S`]"
echo "##############"
echo "$1" > /tmp/PG_VERSION
echo "$2" > /tmp/SERVERID
echo "$3" > /tmp/PRIMARY_SERVER
PG_VERSION=$(cat /tmp/PG_VERSION)

##### FIREWALLD DISABLE ########################
systemctl disable firewalld
systemctl stop firewalld
######### SELINUX ###############################
sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
# disable selinux on the fly
/usr/sbin/setenforce 0

### clean yum cache ###
yum clean headers
yum clean packages
yum clean metadata

####### PACKAGES ###########################
# -------------- For RHEL/CentOS 7 --------------
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install epel-release

### remove old packages ####
yum -y remove postgres
yum -y remove 'postgres*'

### install pre-packages ####
yum -y install screen expect nload bmon iptraf glances perl perl-DBI openssl pigz zlib file sudo  libaio rsync snappy net-tools wget nmap htop dstat sysstat perl-IO-Socket-SSL perl-Digest-MD5 perl-TermReadKey socat libev gcc zlib zlib-devel openssl openssl-devel python-pip python-devel zip

#### REPO Pg ######
# -------------- For RHEL/CentOS 7 --------------
yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

### clean yum cache ###
yum clean headers
yum clean packages
yum clean metadata

### installation of Posgresql via yum ####
yum -y install postgresql$PG_VERSION postgresql$PG_VERSION-server
yum -y install perl-DBD-Pg postgresql$PG_VERSION-python

### Percona #####
### https://www.percona.com/doc/percona-server/LATEST/installation/yum_repo.html
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y
yum -y install percona-toolkit sysbench

##### SYSCTL PG ###########################
# insert parameters into /etc/sysctl.conf for incresing Postgresql limits
echo "# Postgresql preps
vm.swappiness = 1
fs.suid_dumpable = 1
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.shmmni = 4096
# semaphores: semmsl, semmns, semopm, semmni
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default=4194304
net.core.rmem_max=4194304
net.core.wmem_default=262144
net.core.wmem_max=1048586" > /etc/sysctl.conf

# RELOAD CONFIGS ON /etc/sysctl.conf
sysctl -p

#####  Pg LIMITS ###########################

echo ' ' >> /etc/security/limits.conf
echo '# POSTGRES' >> /etc/security/limits.conf
echo 'postgres              soft    nproc   2047' >> /etc/security/limits.conf
echo 'postgres              hard    nproc   16384' >> /etc/security/limits.conf
echo 'postgres              soft    nofile  4096' >> /etc/security/limits.conf
echo 'postgres              hard    nofile  65536' >> /etc/security/limits.conf
echo 'postgres              soft    stack   10240' >> /etc/security/limits.conf
echo '# all_users' >> /etc/security/limits.conf
echo '* soft nofile 102400' >> /etc/security/limits.conf
echo '* hard nofile 102400' >> /etc/security/limits.conf

#####  Pg LIMITS ###########################
mkdir -p /etc/systemd/system/postgresql.service.d/
echo ' ' > /etc/systemd/system/postgresql.service.d/limits.conf
echo '# postgres' >> /etc/systemd/system/postgresql.service.d/limits.conf
echo '[Service]' >> /etc/systemd/system/postgresql.service.d/limits.conf
echo 'LimitNOFILE=102400' >> /etc/systemd/system/postgresql.service.d/limits.conf
echo ' ' > /etc/systemd/system/postgresql.service.d/timeout.conf
echo '# postgres' >> /etc/systemd/system/postgresql.service.d/timeout.conf
echo '[Service]' >> /etc/systemd/system/postgresql.service.d/timeout.conf
echo 'TimeoutSec=28800' >> /etc/systemd/system/postgresql.service.d/timeout.conf
systemctl daemon-reload

##### CONFIG PROFILE #############
echo ' ' >> /etc/profile
echo '# postgres' >> /etc/profile
echo 'if [ $USER = "postgres" ]; then' >> /etc/profile
echo '  if [ $SHELL = "/bin/bash" ]; then' >> /etc/profile
echo '    ulimit -u 16384 -n 65536' >> /etc/profile
echo '  else' >> /etc/profile
echo '    ulimit -u 16384 -n 65536' >> /etc/profile
echo '  fi' >> /etc/profile
echo 'fi' >> /etc/profile

echo "##############"
echo "END - [`date +%d/%m/%Y" "%H:%M:%S`]"
