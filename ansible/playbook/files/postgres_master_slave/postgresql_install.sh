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
# yum -y install epel-release

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
yum -y install perl-DBD-Pg postgresql$PG_VERSION-python postgresql$PG_VERSION-contrib

### Percona #####
### https://www.percona.com/doc/percona-server/LATEST/installation/yum_repo.html
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y
yum -y install percona-toolkit sysbench

#####  POSTGRES LIMITS ###########################
check_limits=$(cat /etc/security/limits.conf | grep '# postgres-pre-reqs' | wc -l)
if [ "$check_limits" == "0" ]; then
echo ' ' >> /etc/security/limits.conf
echo '# postgres-pre-reqs' >> /etc/security/limits.conf
echo 'postgres              soft    nproc   102400' >> /etc/security/limits.conf
echo 'postgres              hard    nproc   102400' >> /etc/security/limits.conf
echo 'postgres              soft    nofile  102400' >> /etc/security/limits.conf
echo 'postgres              hard    nofile  102400' >> /etc/security/limits.conf
echo 'postgres              soft    stack   102400' >> /etc/security/limits.conf
echo 'postgres              soft    core unlimited' >> /etc/security/limits.conf
echo 'postgres              hard    core unlimited' >> /etc/security/limits.conf
echo '# all_users' >> /etc/security/limits.conf
echo '* soft nofile 102400' >> /etc/security/limits.conf
echo '* hard nofile 102400' >> /etc/security/limits.conf
else
echo "PostgreSQL Pre-reqs for /etc/security/limits.conf is already in place!"
fi

##### CONFIG PROFILE #############
check_profile=$(cat /etc/profile | grep '# postgres-pre-reqs' | wc -l)
if [ "$check_profile" == "0" ]; then
echo ' ' >> /etc/profile
echo '# postgres-pre-reqs' >> /etc/profile
echo 'if [ $USER = "postgres" ]; then' >> /etc/profile
echo '  if [ $SHELL = "/bin/bash" ]; then' >> /etc/profile
echo '    ulimit -u 65536 -n 65536' >> /etc/profile
echo '  else' >> /etc/profile
echo '    ulimit -u 65536 -n 65536' >> /etc/profile
echo '  fi' >> /etc/profile
echo 'fi' >> /etc/profile
else
echo "PostgreSQL Pre-reqs for /etc/profile is already in place!"
fi

##### SYSCTL MYSQL ###########################
check_sysctl=$(cat /etc/sysctl.conf | grep '# postgres-pre-reqs' | wc -l)
if [ "$check_sysctl" == "0" ]; then
# insert parameters into /etc/sysctl.conf for incresing MySQL limits
echo "# postgres-pre-reqs
# virtual memory limits
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 40
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
fs.suid_dumpable = 1
vm.nr_hugepages = 0
# file system limits
fs.aio-max-nr = 1048576
fs.file-max = 6815744
# kernel limits
kernel.panic_on_oops = 1
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.shmmni = 4096
# kernel semaphores: semmsl, semmns, semopm, semmni
kernel.sem = 250 32000 100 128
# networking limits
net.ipv4.ip_local_port_range = 9000 65499
net.core.rmem_default=4194304
net.core.rmem_max=4194304
net.core.wmem_default=262144
net.core.wmem_max=1048586" >> /etc/sysctl.conf
else
echo "PostgreSQL Pre-reqs for /etc/sysctl.conf is already in place!"
fi
# reload confs of /etc/sysctl.confs
sysctl -p

#####  Pg LIMITS ###########################
mkdir -p /etc/systemd/system/postgresql.service.d/
echo '[Service]' > /etc/systemd/system/postgresql.service.d/limits.conf
echo 'LimitNOFILE=102400' >> /etc/systemd/system/postgresql.service.d/limits.conf
echo '[Service]' > /etc/systemd/system/postgresql.service.d/timeout.conf
echo 'TimeoutSec=28800' >> /etc/systemd/system/postgresql.service.d/timeout.conf
systemctl daemon-reload

echo "##############"
echo "END - [`date +%d/%m/%Y" "%H:%M:%S`]"
