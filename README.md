VitalPBX Application Server Setup
=====
Sometimes it is necessary to have certain applications on a server that is not the same one that handles phone calls. For example, if we want the Sonata Suite to be on a separate server.
In this manual we will explain the steps to follow to achieve this goal.

## Example:<br>
![VitalPBX HA](https://github.com/VitalPBX/vitalpbx_add_application_server/blob/master/APPReplicaServers.png)

-----------------
## Prerequisites
In order to install VitalPBX the App Server you need the following:<br>
a.- 2 IP addresses.<br>
b.- Install VitalPBX version 3 or higher on two servers.<br>
c.- MariaDB (include in VitalPBX 3)<br>
d.- Lsyncd.<br>

## Configurations
We will configure in each server the IP address and the host name. Go to the web interface to: <strong>Admin>System Settinngs>Network Settings</strong>.<br>
First change the Hostname, remember press the <strong>Check</strong> button.<br>
Disable the DHCP option and set these values<br>

| Name          | Master                 | App                   |
| ------------- | ---------------------- | --------------------- |
| Hostname      | vitalpbx1.local        | vitalpbx2.local       |
| IP Address    | 192.168.10.61          | 192.168.10.62         |
| Netmask       | 255.255.255.0          | 255.255.255.0         |
| Gateway       | 192.168.10.1           | 192.168.10.1          |
| Primary DNS   | 8.8.8.8                | 8.8.8.8               |
| Secondary DNS | 8.8.4.4                | 8.8.4.4               |

## Installing the necessary software dependencies
We will constantly make copies of files from the Server 1 to the application server. For this we need to install lsync in Server 1. The information from Server 1 will be copied to Server 2<br>
<pre>
[root@vitalpbx<strong>1<strong> ~]# yum -y install lsyncd
</pre>

## Create authorization key
Create authorization key for the Access from the Server <strong>1</strong> to Server <strong>2</strong> without credentials.
<pre>
[root@vitalpbx<strong>1</strong> ~]# ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
[root@vitalpbx<strong>1</strong> ~]# ssh-copy-id root@<strong>192.168.10.62</strong>
Are you sure you want to continue connecting (yes/no)? <strong>yes</strong>
root@192.168.10.62's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.62'"
and check to make sure that only the key(s) you wanted were added. 

[root@vitalpbx<strong>1</strong> ~]#
</pre>

## Installing from Scripts
Now copy and run the following script<br>
<pre>
[root@ vitalpbx<strong>1</strong> ~]# mkdir /usr/share/vitalpbx/appserver
[root@ vitalpbx<strong>1</strong> ~]# cd /usr/share/vitalpbx/appserver
[root@ vitalpbx<strong>1</strong> ~]# wget https://raw.githubusercontent.com/VitalPBX/vitalpbx_add_application_server/master/vpbxappserver.sh
[root@ vitalpbx<strong>1</strong> ~]# chmod +x vpbxappserver.sh
[root@ vitalpbx<strong>1</strong> ~]# ./vpbxappserver.sh

************************************************************
*     Welcome to the VitalPBX App Server installation      *
*                All options are mandatory                 *
************************************************************
IP Master................ > <strong>192.168.10.61</strong>
IP Application........... > <strong>192.168.10.62</strong>
************************************************************
*                   Check Information                      *
*        Make sure you have internet on both servers       *
************************************************************
Are you sure to continue with this settings? (yes,no) > <strong>yes</strong>
</pre>

## Installing Sonata Switchboard in Server 2
Now we are going to connect to Server <strong>2</strong> to install Sonata Switchboard, for which we are going to Admin/Add-Ons/Add-Ons.

In Server <strong>1</strong> we are going to create an Api Key through which Sonata Switchboard will be connected, for which we are going to Admin/Admin/Application Keys. We create the API Key that works in all Tenants and then we edit it to copy the value.

In the Server <strong>2</strong> console we are going to execute the following command to update the connection values of Sonata Switchboard.:

<pre>
[root@ vitalpbx<strong>3</strong> ~]# mysql -uroot astboard -e "UPDATE pbx SET host='192.168.10.60', remote_host='yes', api_key='babf43dbf6b8298f46e3e7381345afbf '"
[root@ vitalpbx<strong>3</strong> ~]# sed -i -r 's/localhost/192.168.10.60/' /usr/share/sonata/switchboard/monitor/config.ini
[root@ vitalpbx<strong>3</strong> ~]# systemctl restart switchboard
</pre>
Remember to change the Api Key for the value copied in the previous step.

Notes:<br>
•	The Sonata Switchboard license must be installed on the Master Server. This is because Sonata Switchboard connects directly to the Master Server via API and it needs to display the information in real time.
•	You can install Sonata Recording, Sonata Billing, and Sonata Stats on the application server. In this case the license must be on the application server. No additional configuration is necessary.

## More Information
If you want more information that will help you solve problems about High Availability in VitalPBX we invite you to see the following manual<br>
[Add Application Server Manual, step by step](https://github.com/VitalPBX/vitalpbx_ha_app_server/raw/master/VitalPBX3.0AppServerSetup.pdf)

<strong>CONGRATULATIONS</strong>, you have installed and tested the high availability in <strong>VitalPBX 3</strong><br>
:+1:
