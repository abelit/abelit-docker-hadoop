#! /bin/bash

#===============================================================================================
#   System Required:  Linux/Unix-Like and MacOSX
#   Version: 3.1415
#   Modified: 2017-05-24
#   Author: Abelit <ychenid@live.com>
#   Description: Build Hadoop and Spark Cluster Based on CentOS and Ubuntu 16.04
#   Intro: http://www.dockertime.com
#===============================================================================================

# Set shell environment
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# clear

# Define variable --------------Begin---------------------
# Check system information
osname=`uname -s`

# Define hadoop and spark's path
current_path=`pwd`

# Define docker image name or tag
hadoop_image="ubuntu:hadoop"

# Define datanode or slaves node numbers
node_num=5

# Parameter of this script
param=$1

# Define file known_hosts and its path
containerconf_path="$current_path/containerconf"
containerconf_known_hosts="$containerconf_path/known_hosts"
containerconf_hosts="$containerconf_path/hosts"
containerconf_bashrc="$containerconf_path/bash.bashrc"

# Define hadoop and its conf's path on local
hadoop_home="$current_path"
hadoop_hdfs_path="$hadoop_home/hdfs"
hadoopconf_path="$hadoop_home/hadoopconf"
hadoopconf_slaves="$hadoopconf_path/slaves"
hadoopconf_coresite="$hadoopconf_path/core-site.xml"
hadoopconf_hdfssite="$hadoopconf_path/hdfs-site.xml"
hadoopconf_mapredsite="$hadoopconf_path/mapred-site.xml"
hadoopconf_yarnsite="$hadoopconf_path/yarn-site.xml"
hadoopconf_hadoopenv="$hadoopconf_path/hadoop-env.sh"
hadoopconf_mapredenv="$hadoopconf_path/mapred-env.sh"
hadoopconf_yarnenv="$hadoopconf_path/yarn-env.sh"

# Define hadoop and its conf's path on the container
container_hadoop_home="/root/hadoop/hadoop-2.7.3"
container_hadoop_hdfs_path=$container_hadoop_home/hdfs
container_hadoopconf_path=$container_hadoop_home/etc/hadoop

# Define spark and its conf's path
spark_home="$current_path"
sparkconf_path="$spark_home/sparkconf"
sparkconf_env="$sparkconf_path/spark-env.sh"
sparkconf_slaves="$sparkconf_path/slaves"

# Define spark and its conf's path on the container
container_spark_home="/root/hadoop/spark-2.0.2-bin-hadoop2.7"
container_sparkconf_path=$container_spark_home/conf
# Define variable --------------End----------------------

# Configure soft path environment
function addPath() {
		# Check container's path
		if [ -d "$containerconf_path" ];then
			# Make sure there exits known_hosts
			if [ ! -e "$containerconf_known_hosts" ];then
				touch $containerconf_known_hosts
			fi
			if [ ! -e "$containerconf_hosts" ];then
				touch $containerconf_hosts
			fi
		else
			mkdir  -p $containerconf_path
			if [ ! -e "$containerconf_hosts" ];then
				touch $containerconf_hosts
			fi
		fi
}

# Make sure only root can run this script
function isRoot() {
	if [[ $EUID -ne 0 ]]; then
		echo "Error:This script must be run as root!" 1>&2
		exit 1
	fi
}

# Make sure the docker has been installed
function isDocker() {
	dk=`which docker`
	if [[ "$dk" = "" ]];then
		echo "Warnning: !! No docker service installed on your system."
		echo "Now docker service will be installed on your system,please install docker before executing this script ..."
		exit 1
	else
		# Check version of docker
		dkversion=`docker -v`
		echo "$dkversion has been installed."
	fi
}


# Start docker service
function startDocker() {
	isrun=`docker ps -a`
	if [[ ! -n "$isrun" ]]; then
		if [[ "$osname" = "Linux" ]];then
			echo "You are using Linux OS, the linux kernerl is `uname -rp`."
			echo "Now starting docker service..."
			systemctl restart docker.service
		elif [[ "$osname" = "Darwin" ]]; then
			echo "You are using MacOSX, please start docker service by manual."
			exit 1
		else
			echo "The script is noly running based on Linux/Unix-Like system. Please make sure your system is Linux/Unix-Like."
			exit 1
	  fi
	else
		echo "Docker is running."
	fi
}

function startMaster() {
	master_container='master'
	#Start a master hadoop container
	docker run -t -d --name master -h master -v $containerconf_bashrc:/etc/bash.bashrc -v $containerconf_known_hosts:/root/.ssh/known_hosts -v $containerconf_hosts:/etc/hosts -v $hadoopconf_path:$container_hadoopconf_path -v $hadoop_hdfs_path/$master_container:$container_hadoop_hdfs_path $hadoop_image
	master_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' $master_container)

	echo ""
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "The namenode(master) has been started."
	echo "The name of container:${master_container}."
	echo "The IPAddress: ${master_ip}"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo ""
	echo "$master_ip    $master_container" >> $containerconf_hosts
}

function startSlave() {
	#Start some slave hadoop container (Datanode/Slaves)
	echo "Please the number of Datanode that you want to build: "
	read -p "(Default will create $node_num datanodes):" number

	if [ "$number" = "" ];then
		number=$node_num
	fi

	# Clearing hadoop slaves
	sed -ie '/^slave.*/d' $hadoopconf_slaves
	sed -ie '/^$/d' $hadoopconf_slaves
	# Clearing spark slaves
	sed -ie '/^slave.*/d' $sparkconf_slaves
	sed -ie '/^$/d' $sparkconf_slaves

	while [ $number -gt 0 ]
	do
		slave_container="slave${number}"
		# Configuring hadoop slaves configuration
		echo $slave_container >> $hadoopconf_slaves

		# Configuring hadoop slaves configuration
		echo $slave_container >> $sparkconf_slaves

		docker run -t -d --name slave${number} -h slave${number} -v $containerconf_bashrc:/etc/bash.bashrc -v $containerconf_known_hosts:/root/.ssh/known_hosts -v $containerconf_hosts:/etc/hosts -v $hadoopconf_path:$container_hadoopconf_path -v $hadoop_hdfs_path/slave${number}:$container_hadoop_hdfs_path $hadoop_image
		slave_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' $slave_container)

		echo ""
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "The datanode slave${number} has been started."
		echo "The name of container:${slave_container}."
		echo "The IPAddress: ${slave_ip}"
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
		echo "$slave_ip    $slave_container" >> $containerconf_hosts
		number=$[ $number-1 ]
	done
}

#Use Hadoop
function enterContainer(){
	echo "Now you can go to the node of hadoop. Default you will go to the master node."
	echo "If you don't know which node you have started and you can input 'node' to show."
	echo "Please input the name of node you will go to:"
	read -p "(Default is master node.):" node
	if [ "$node" = "" ];then
		node='master'
	else
		if [ "$node" = "node" ];then
			container_lists="`docker ps | grep -E "slave|master|secondarynamenode" | awk '{print $NF}'`"
			echo $container_lists
			enterContainer
		fi
		node=$node
	fi
	# Using node by interactive
	docker exec -it $node /bin/bash
}

#Reset Docker Parameters
function resetDocker() {
	# Clear known_hosts contents
	echo "Clear hosts contents ..."
	cat /dev/null > $containerconf_hosts

	# Clear known_hosts contents
	echo "Clear known_hosts contents ..."
	cat /dev/null > $containerconf_known_hosts

	container_lists="`docker ps | grep -E "slave|master|secondarynamenode" | awk '{print $NF}'`"
	for container_name in $container_lists
	do
		echo "Stopping Container $container_name ..."
		docker stop $container_name
		echo "The Hadoop Node $container_name has been stoped! "
	done

	#Romove Container
	container_lists="`docker ps -a | grep -E "slave|master|secondarynamenode" | awk '{print $NF}'`"
	for container_name in $container_lists
	do
		echo "Removing Container $container_name ..."
		docker rm $container_name
		echo "The Hadoop Node $container_name has been removed! "
	done
}

# Check the status of container
function checkContainer() {
	container_running_lists="`docker ps | grep -E "slave|master|secondarynamenode"`"
	container_exist_lists="`docker ps -a | grep -E "slave|master|secondarynamenode"`"
	if [ "$container_running_lists" != "" ];then
		#Running
		echo "There have some running hadoop container."
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		docker ps | grep -E "slave|master|secondarynamenode"
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
	else
		echo "No hadoop container is running."
	fi

	if [ "$container_exist_lists" != "" ];then
		#Running
		echo "There have some created hadoop container."
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		docker ps -a | grep -E "slave|master|secondarynamenode"
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
	else
		echo "No hadoop container exists."
	fi
}

#SSH Configuration in the container
# function sshConf() {
# 	container_lists="`docker ps | grep -E "slave|master|secondarynamenode" | awk '{print $NF}'`"
# 	for container in $container_lists
# 	do
# 		container_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' $container)
# 		known_hosts="$container,$container_ip"
# 		known_hosts=$known_hosts" ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNhSjuhiLxYqNBQPnwUKQJlPfs/lqHPGwMxcT5D9saXXZ6gb75f22Yn1ClRmktzh29vOziEMCMgm3iOiQ/UOdak="
# 		echo $known_hosts >> $containerconf_known_hosts
# 	done
# }

function logo() {
	#Make Symble Start
	echo " HH    HH       AA        DDDDDD    OOOOOOOO OOOOOOOO PPPPPPPP "
	echo " HH    HH      AA AA      DD    DD  OO    OO OO    OO PP    PP "
	echo " HH    HH     AA   AA     DD     DD OO    OO OO    OO PP    PP "
	echo " HHHHHHHH    AAAAAAAAA    DD     DD OO    OO OO    OO PPPPPPPP "
	echo " HH    HH   AA       AA   DD     DD OO    OO OO    OO PP       "
	echo " HH    HH  AA         AA  DD    DD  OO    OO OO    OO PP       "
	echo " HH    HH AA           AA DDDDDD    OOOOOOOO OOOOOOOO PP       "
}

function author() {
	# Show author's info.
	echo "Welcome to use hadoop built on docker container! Good luck for you!"
	echo "########################################################################"
	echo "# Build Hadoop Cluster and Spark Based on Linux/Unix-Like and MacOSX   #"
	echo "# Version:3.1415                                                       #"
	echo "# Author: Abelit <ychenid@live.com>                                    #"
	echo "# Intro: http://www.dockertime.com                                     #"
	echo "#                                                                      #"
	echo "########################################################################"
	echo ""
}

function sucessInfo() {
	#Show Result of Installation
	echo ""
	echo "*******************************************************************************************"
	echo "*******************************************************************************************"
	echo "Congradulations! Hadoop Cluster has been Built and Insltalled successfully. "
	echo "*******************************************************************************************"
	echo "*******************************************************************************************"
	echo ""
}

#Run Hadoop Container
function startContainer() {
	# echo "Verifing privilege of the user ..."
	# isRoot
	echo "Checking docke package ..."
	isDocker
	echo "Creating prerequirements directories ..."
	addPath
	echo "Starting docker engine ..."
	sleep 2
	startDocker
	echo "Starting container ..."
	startMaster
	startSlave
	# echo "Conguring ssh ..."
	# sshConf
	# echo "Restarting dns ..."
	# restartDNS
	echo "All services are started successfully."
	sucessInfo
	enterContainer
}

#The Header Information
function startup() {
	author
	logo
	echo ""

	echo "This shell script will build hadoop cluster based on the virtulization of docker:"
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Notice!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "There maybe have some container you have ever created.And you should "
	echo "clear and remove them before build new container."
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Notice!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

	echo "1. Clear and Remove Hadoop Container all that have been created!"
	echo "2. Build Hadoop Cluster Using Docker. "
	echo "3. Look up created or running Hadoop Container."
	echo "4. Enter into container to manage it."
	echo "Others to Exit. "
	echo "Please input the number:"
	read num
	case "${num}" in
	[1] ) (resetDocker);;
	[2] ) (startContainer);;
	[3] ) (checkContainer);;
	[4] ) (enterContainer);;
	 *  ) echo "Nothing you will do.";;
	esac
}

function manPage() {
	echo "-h or --help : Lookup help information and usage."
	echo ""
}

startup
