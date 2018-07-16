#!/bin/sh
device=lo
MASTER=/home/mesasoft/redis_master/
SLAVE_MASTER=/home/mesasoft/redis_global_slave_master/
SLAVE=/home/mesasoft/redis_global_slave/


function redis_master
{
	cp -r redis_master /home/mesasoft/
	cp redis-master-daemon.service /usr/lib/systemd/system/
	cp redis-master.service	/etc/systemd/system/

	systemctl enable redis-master-daemon.service
	systemctl enable redis-master.service
	systemctl daemon-reload

	sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $MASTER/redis_master.conf
	sed -i "s/127.0.0.1/`ifconfig $device | grep netmask | awk '{print $2}'`/g" $MASTER/reset_redis4maat.sh

	chmod 777 $MASTER/redis_master_daemon
	systemctl start redis-master-daemon
	sleep 5
	chmod 777 $MASTER/reset_redis4maat.sh
	cd $MASTER/; ./reset_redis4maat.sh; cd -	
}

function redis_slave_master
{
	cp -r redis_global_slave_master /home/mesasoft/

	cp redis-global-slave-master-daemon.service /usr/lib/systemd/system/
	cp redis-global-slave-master.service /etc/systemd/system/

	sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $SLAVE_MASTER/redis_global_slave_master.conf
	sed -i "s/slaveof 10.0.6.202 6379/slaveof $1 $2/g" $SLAVE_MASTER/redis_global_slave_master.conf

	systemctl enable redis-global-slave-master-daemon.service
	systemctl enable redis-global-slave-master.service
	systemctl daemon-reload

	chmod 777 $SLAVE_MASTER/redis_global_slave_master_daemon
	systemctl start redis-global-slave-master-daemon
}

function redis_slave
{
	cp -r redis_global_slave /home/mesasoft/
	for((i=6380; i<=6389;i++))
	do
		mkdir $SLAVE$i/ -p
		cp $SLAVE/redis_global_slave.conf $SLAVE$i/redis$i.conf
		sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $SLAVE$i/redis$i.conf
		sed -i "s/slaveof 127.0.0.1 6379/slaveof $1 $2/g" $SLAVE$i/redis$i.conf
		sed -i "s/port 6379/port $i/g" $SLAVE$i/redis$i.conf
		sed -i "s/redis_6379.pid/`echo "redis_$i.pid"`/g" $SLAVE$i/redis$i.conf
	done

	chmod 777 $SLAVE/r2
	chmod 777 $SLAVE/redis_global_slave_daemon
	cd $SLAVE; ./r2; cd -
}

function redis_help
{
	echo "mode: master/slave_master/slave"	
	echo "master ./install.sh eno1 master"	
	echo "slave_master ./install.sh eno1 slave_master redis_ip redis_port"	
	echo "slave ./install.sh eno1 slave redis_ip redis_port"	
}

if [[ $# -lt 2 ]];then
	redis_help
	exit 0
else
	device=$1
fi

if [[ `locate redis-server | grep /usr/local/bin/redis-server | wc -l` -lt 1 ]]; then
	tar zxvf redis-3.2.9.tar.gz
	cd redis-3.2.9/; make; make install; cd -
	mkdir /home/mesasoft/ -p
fi

SLAVEOF_IP=$3
SLAVEOF_PORT=$4
case $2 in
	master)
	redis_master $MASTER
	;;
	slave_master)
	redis_slave_master $SLAVEOF_IP $SLAVEOF_PORT
	;;
	slave)
	redis_slave $SLAVEOF_IP $SLAVEOF_PORT
	;;
	*)
	redis_help	
	;;
esac

rm -rf redis-3.2.9
