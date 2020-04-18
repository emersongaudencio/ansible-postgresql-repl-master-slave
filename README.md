# Ansible PostgreSQL Replication Master-Slave
###  Ansible Routine to setup Master/Slave replication streaming on PostgreSQL

# Translation in English en-us

In this file, I will present and demonstrate how to install PostgreSQL Master-Slave replication in an automated and easy way.

For this, I will be using the scenario described down below:
```
1 Linux server for Ansible
2 Linux servers for PostgreSQL (the one that we will install PostgreSQL using Ansible)
```

First of all, we have to prepare our Linux environment to use Ansible

Please have a look below how to install Ansible on CentOS/Red Hat:
```
yum install ansible -y
```
Well now that we have Ansible installed already, we need to install git to clone our git repository on the Linux server, see below how to install it on CentOS/Red Hat:
```
yum install git -y
```

Copying the script packages using git:
```
cd /root
git clone https://github.com/emersongaudencio/ansible-postgresql-repl-master-slave.git
```
Alright then after we have installed Ansible and git and clone the git repository. We have to generate ssh heys to share between the Ansible control machine and the database machines. Let see how to do that down below.

To generate the keys, keep in mind that is mandatory to generate the keys inside of the directory who was copied from the git repository, see instructions below:
```
cd /root/ansible-postgresql-repl-master-slave/ansible
ssh-keygen -f ansible
```
After that you have had generated the keys to copy the keys to the database machines, see instructions below:
```
ssh-copy-id -i ansible.pub 172.16.122.128
```

Please edit the file called hosts inside of the ansible git directory :
```
vi hosts
```
Please add the hosts that you want to install your database and save the hosts file, see an example below:

```
# This is the default ansible 'hosts' file.
#


## [dbservers]
##
## db01.intranet.mydomain.net
## db02.intranet.mydomain.net
## 10.25.1.56
## 10.25.1.57

[pgcluster]
db95master ansible_ssh_host=172.16.122.152
db95slave ansible_ssh_host=172.16.122.151
db96master ansible_ssh_host=172.16.122.150
db96slave ansible_ssh_host=172.16.122.149
db10master ansible_ssh_host=172.16.122.131
db10slave ansible_ssh_host=172.16.122.132
db11master ansible_ssh_host=172.16.122.128
db11slave ansible_ssh_host=172.16.122.153
db12master ansible_ssh_host=172.16.122.141
db12slave ansible_ssh_host=172.16.122.142
```

For testing if it is all working properly, run the command below :
```
ansible -m ping db11master -v
ansible -m ping db11slave -v
```
Alright finally we can install our PostgreSQL 11 using Ansible as we planned to, run the command below:
```
sh run_postgres_master_slave_install.sh db11master 11 100 172.16.122.128
sh run_postgres_master_slave_install.sh db11slave 11 100 172.16.122.128
```

### Parameters specification:
#### run_postgres_master_slave_install.sh
Parameter    | Value           | Mandatory   | Order        | Accepted values
------------ | ------------- | ------------- | ------------- | -------------
hostname or group-name listed on hosts files | db11master | Yes | 1 | hosts who are placed inside of the hosts file
db postgresql version | 11 | Yes | 2 | 94,95,96,10,11,12
db postgresql server id | 100 | Yes | 3 | integer unique number between 1 to 1024 to identify primary server
db postgresql primary server address | 172.16.122.128 | Yes | 4 | primary server ip address or dns name respective

PS: Just remember that you can do a single installation at the time or a group installation you inform the name of the group in the hosts' files instead of the host itself.

The PostgreSQL versions supported for this script are these between the round brackets (95, 96, 10, 11, 12).

PostgreSQL 9.5 has been tested successfully.
PostgreSQL 9.6 has been tested successfully.
PostgreSQL 10 has been tested successfully.
PostgreSQL 11 has been tested successfully.
PostgreSQL 12 has been tested successfully.
