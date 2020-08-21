#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 19-Aug-2020
# VitalPBX Application Server Installation with MariaDB Replica and Lsync
#
set -e
function jumpto
{
    label=$start
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

echo -e "\n"
echo -e "************************************************************"
echo -e "*     Welcome to the VitalPBX App Server installation      *"
echo -e "*               All options are mandatory                  *"
echo -e "************************************************************"

filename="config.txt"
if [ -f $filename ]; then
	echo -e "config file"
	n=1
	while read line; do
		case $n in
			1)
				ip_master=$line
  			;;
			2)
				ip_app=$line
  			;;
		esac
		n=$((n+1))
	done < $filename
	echo -e "IP Master................ > $ip_master"	
	echo -e "IP App Server............ > $ip_app"
fi

while [[ $ip_master == '' ]]
do
    read -p "IP Master................ > " ip_master 
done 

while [[ $ip_app == '' ]]
do
    read -p "IP App Server............ > " ip_app 
done

echo -e "************************************************************"
echo -e "*                   Check Information                      *"
echo -e "*        Make sure you have internet on both servers       *"
echo -e "************************************************************"
while [[ $veryfy_info != yes && $veryfy_info != no ]]
do
    read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
done

if [ "$veryfy_info" = yes ] ;then
	echo -e "************************************************************"
	echo -e "*                Starting to run the scripts               *"
	echo -e "************************************************************"
else
    	exit;
fi

cat > config.txt << EOF
$ip_master
$ip_app
EOF

stepFile=step.txt
if [ -f $stepFile ]; then
	step=`cat $stepFile`
else
	step=0
fi

echo -e "Start in step: " $step

start="create_auth_key"
case $step in
	1)
		start="create_auth_key"
  	;;
	2)
		start="rename_tenant_id_in_server2"
  	;;
	3)
		start="configuring_firewall"
  	;;
	4)
		start="create_ami_user"
  	;;	
	5)
		start="create_lsyncd_config_file"
  	;;
	6)
		start="create_mariadb_replica"
	;;
esac
jumpto $start

echo -e "*** Done Step 1 ***"
echo -e "1"	> step.txt

create_auth_key:
echo -e "************************************************************"
echo -e "*               Create Authorization Key                   *"
echo -e "************************************************************"
sshKeyFile=/root/.ssh/id_rsa
if [ ! -f $sshKeyFile ]; then
	ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
fi
ssh-copy-id root@$ip_app
echo -e "*** Done Step 2 ***"
echo -e "2"	> step.txt

rename_tenant_id_in_server2:
echo -e "************************************************************"
echo -e "*                Remove Tenant in Server 2                 *"
echo -e "************************************************************"
remote_tenant_id=`ssh root@$ip_app "ls /var//lib/vitalpbx/static/"`
ssh root@$ip_app "rm -rf /var/lib/vitalpbx/static/$remote_tenant_id"
echo -e "*** Done Step 3 ***"
echo -e "3"	> step.txt

configuring_firewall:
echo -e "************************************************************"
echo -e "*             Configuring Temporal Firewall                *"
echo -e "************************************************************"
#Create temporal Firewall Rules in Server 1 and 2
firewall-cmd --permanent --zone=public --add-port=3306/tcp
firewall-cmd --reload
ssh root@$ip_app "firewall-cmd --permanent --zone=public --add-port=3306/tcp"
ssh root@$ip_app "firewall-cmd --reload"

echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*   Creating Firewall Services in VitalPBX in Server 1     *"
echo -e "************************************************************"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('MariaDB Client', 'tcp', '3306')"
echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*     Creating Firewall Rules in VitalPBX in Server 1      *"
echo -e "************************************************************"
last_index=$(mysql -uroot ombutel -e "SELECT MAX(\`index\`) AS Consecutive FROM ombu_firewall_rules"  | awk 'NR==2')
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'MariaDB Client'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_master', 'Server 1 IP', 'no')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_app', 'Server 2 IP', 'no')"
echo -e "*** Done Step 4 ***"
echo -e "4"	> step.txt

create_ami_user:
echo -e "************************************************************"
echo -e "*                   Creating AMI User                      *"
echo -e "************************************************************"
cat > /etc/asterisk/vitalpbx/manager__50-astboard-user.conf << EOF
[astboard]
secret = astboard
deny = 0.0.0.0/0.0.0.0
permit= 0.0.0.0/0.0.0.0
read = all
write = all
writetimeout = 5000
eventfilter=!Event: RTCP*
eventfilter=!Event: VarSet
eventfilter=!Event: Cdr
eventfilter=!Event: DTMF
eventfilter=!Event: AGIExec
eventfilter=!Event: ExtensionStatus
eventfilter=!Event: ChannelUpdate
eventfilter=!Event: ChallengeSent
eventfilter=!Event: SuccessfulAuth
eventfilter=!Event: NewExten
EOF
chown apache:root /etc/asterisk/vitalpbx/manager__50-astboard-user.conf
systemctl restart asterisk
echo -e "*** Done Step 5 ***"
echo -e "5"	> step.txt

create_lsyncd_config_file:
echo -e "************************************************************"
echo -e "*              Configure lsync in Server 1                 *"
echo -e "************************************************************"
if [ ! -d "/var/spool/asterisk/monitor" ] ;then
	mkdir /var/spool/asterisk/monitor
fi
chown asterisk:asterisk /var/spool/asterisk/monitor

ssh root@$ip_app [[ ! -d /var/spool/asterisk/monitor ]] && ssh root@$ip_app "mkdir /var/spool/asterisk/monitor" || echo "Path exist";
ssh root@$ip_app "chown asterisk:asterisk /var/spool/asterisk/monitor"

cat > /etc/lsyncd.conf << EOF
----
-- User configuration file for lsyncd.
--
-- Simple example for default rsync.
--
settings {
		logfile    = "/var/log/lsyncd/lsyncd.log",
		statusFile = "/var/log/lsyncd/lsyncd-status.log",
		statusInterval = 20,
		nodaemon   = true,
		insist = true,
}

sync {
		default.rsync,
		source="/var/spool/asterisk/monitor",
		target="$ip_app:/var/spool/asterisk/monitor",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/",
		target="$ip_app:/var/lib/asterisk/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=astdb.sqlite3",
						"--exclude=*"
						}
				}
	}

sync {
		default.rsync,
		source="/var/lib/asterisk/agi-bin/",
		target="$ip_app:/var/lib/asterisk/agi-bin/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/priv-callerintros/",
		target="$ip_app:/var/lib/asterisk/priv-callerintros",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/sounds/",
		target="$ip_app:/var/lib/asterisk/sounds/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/vitalpbx",
		target="$ip_app:/var/lib/vitalpbx",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,			
				archive = "true",
				_extra = {
						"--exclude=*.lic",
						"--exclude=*.dat",
						"--exclude=dbsetup-done",
						"--exclude=cache"
						}
				}
}

sync {
		default.rsync,
		source="/etc/asterisk",
		target="$ip_app:/etc/asterisk",
		rsync={
				owner = true,
				group = true
		}
}
EOF
echo -e "*** Done Step 6 ***"
echo -e "6"	> step.txt

create_mariadb_replica:
echo -e "************************************************************"
echo -e "*                Create MariaDB Replica                    *"
echo -e "************************************************************"
#Configuration of the First Master Server (Master-1)
cat > /etc/my.cnf.d/vitalpbx.cnf << EOF
[mysqld]
server-id=1
log-bin=mysql-bin
report_host = master

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
systemctl restart mariadb
#Create a new user on the Master-1
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
#Get bin_log on Master-1
file_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $1}'`
position_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $2}'`

#Now on the Master-1 server, do a dump of the database MySQL and import it to Master-2
mysqldump -u root --all-databases > all_databases.sql
scp all_databases.sql root@$ip_app:/tmp/all_databases.sql
cat > /tmp/mysqldump.sh << EOF
#!/bin/bash
mysql mysql -u root <  /tmp/all_databases.sql 
EOF
scp /tmp/mysqldump.sh root@$ip_app:/tmp/mysqldump.sh
ssh root@$ip_app "chmod +x /tmp/mysqldump.sh"
ssh root@$ip_app "/tmp/./mysqldump.sh"

#Configuration of the Second Master Server (Master-2)
cat > /tmp/vitalpbx.cnf << EOF
[mysqld]
server-id = 2
log-bin=mysql-bin
report_host = replica

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
scp /tmp/vitalpbx.cnf root@$ip_app:/etc/my.cnf.d/vitalpbx.cnf
ssh root@$ip_app "systemctl restart mariadb"
#On the Master server
mysql -uroot -e "UNLOCK TABLES;"
#Stop the slave, add Master-1 to the Master-2 and start slave
cat > /tmp/change.sh << EOF
#!/bin/bash
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_master', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_1', MASTER_LOG_POS=$position_server_1;"
mysql -uroot -e "START SLAVE;"
EOF
scp /tmp/change.sh root@$ip_app:/tmp/change.sh
ssh root@$ip_app "chmod +x /tmp/change.sh"
ssh root@$ip_app "/tmp/./change.sh"

echo -e "*** Done Step 7 ***"
echo -e "7"	> step.txt

vitalpbx_cluster_ok:
echo -e "************************************************************"
echo -e "*                VitalPBX App Server OK                    *"
echo -e "*        Now all the information that is updated on        *"
echo -e "*           the Master server will be current on           *"
echo -e "*                 the application server                   *"
echo -e "************************************************************"