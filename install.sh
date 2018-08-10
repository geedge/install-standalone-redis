#!/bin/sh

role=
device=
slaveof_ip=
slaveof_port=
MASTER=/home/mesasoft/redis_master/
SLAVE_MASTER=/home/mesasoft/redis_global_slave_master/
SLAVE=/home/mesasoft/redis_global_slave/

function get_card_by_ip()
{
	echo `ifconfig -a | grep -B 1 $1 | head -n1  | awk -F":" '{print $1}'`
}

function redis_master()
{
	cp -r redis_master /home/mesasoft/
	cp redis-master.service	/etc/systemd/system/

	systemctl enable redis-master.service
	systemctl daemon-reload

	sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $MASTER/redis_master.conf
	sed -i "s/127.0.0.1/`ifconfig $device | grep netmask | awk '{print $2}'`/g" $MASTER/reset_redis4maat.sh

	systemctl start redis-master
	sleep 5
	sed -i 's/
//g' $MASTER/reset_redis4maat.sh
	chmod 777 $MASTER/reset_redis4maat.sh
	cd $MASTER/; ./reset_redis4maat.sh; cd -	
}

function redis_slave_master()
{
	cp -r redis_global_slave_master /home/mesasoft/

	cp redis-global-slave-master.service /etc/systemd/system/

	sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $SLAVE_MASTER/redis_global_slave_master.conf
	sed -i "s/slaveof 10.0.6.202 6379/slaveof $1 $2/g" $SLAVE_MASTER/redis_global_slave_master.conf

	systemctl enable redis-global-slave-master.service
	systemctl daemon-reload

	systemctl start redis-global-slave-master
}

function redis_slave()
{
	cp -r redis_global_slave /home/mesasoft/
	for((i=6380; i<=6389;i++))
	do
		mkdir $SLAVE$i/ -p
		cp $SLAVE/redis_global_slave.conf $SLAVE$i/redis$i.conf
		sed -i "s/bind 127.0.0.1/bind `ifconfig $device | grep netmask | awk '{print $2}'`/g" $SLAVE$i/redis$i.conf
		if [[ -z $1 ]]; then
			sed -i "s/slaveof 127.0.0.1 6379/slaveof `ifconfig $device | grep netmask | awk '{print $2}'` 6379/g" $SLAVE$i/redis$i.conf
		else
			sed -i "s/slaveof 127.0.0.1 6379/slaveof $1 $2/g" $SLAVE$i/redis$i.conf
		fi
		sed -i "s/port 6379/port $i/g" $SLAVE$i/redis$i.conf
		sed -i "s/redis_6379.pid/`echo "redis_$i.pid"`/g" $SLAVE$i/redis$i.conf
	done

	sed -i 's/
//g' $SLAVE/r2
	sed -i 's/
//g' $SLAVE/redis_global_slave_daemon

	chmod 777 $SLAVE/r2
	chmod 777 $SLAVE/redis_global_slave_daemon
	cd $SLAVE; ./r2; cd -
}


function redis_help()
{
	echo "-r|--role):"
	echo "	master/slave_master/slave"	
	echo "-d|--device:"
	echo "	network card"	
	echo "-i|--slaveof_ip:"
	echo "	slaveof ip"	
	echo "-p|--slaveof_port:"
	echo "	slaveof port"	
	echo "-I|--iplist:"
	echo "	iplist"	
	echo ""
	echo "*********************************************************************************"
	echo "*	master									*"
	echo "*		./install.sh -r master -d eth0					*"
	echo "*	slave_master								*"
	echo "*		./install.sh -r slave_master -d eth0 -i 192.168.18.128 -p 6379	*"
	echo "*		./install.sh -r slave -i 192.168.18.128 -p 6379	-I iplist	*"
	echo "*	slave									*"
	echo "*		./install.sh -r slave -d eth0 -i 192.168.18.128 -p 6379	*"
	echo "*		./install.sh -r slave -i 192.168.18.128 -p 6379	-I iplist	*"
	echo "*		./install.sh -r slave -I iplist					*"
	echo "*********************************************************************************"
}


while getopts ":r:d:i:p:I:" ARGS
do
    case $ARGS in
    	r|--role) 
		role=$OPTARG
		;;
	d|--device)
		device=$OPTARG
		;;
	i|--redis-ip)
		slaveof_ip=$OPTARG
		;;
	p|--redis-port)
		slaveof_port=$OPTARG
		;;
	I|--iplist)
		iplist=$OPTARG
		while read ip
		do
			device=`get_card_by_ip $ip`
			if [[ ! -z "$device" ]] ; then
				break;	
			fi
		done < $iplist
		;;
	--) 	
		shift
		break ;;
    esac
done

if [[ `locate redis-server | grep /usr/local/bin/redis-server | wc -l` -lt 1 ]]; then
	tar zxvf redis-3.2.9.tar.gz
	cd redis-3.2.9/; make; make install; cd -
	mkdir /home/mesasoft/ -p
fi

case $role in
	master)
	redis_master
	;;
	slave_master)
	redis_slave_master $slaveof_ip $slaveof_port
	;;
	slave)
	if [[ -z "$slaveof_ip" ]] || [[ -z "$slaveof_port" ]]; then
		redis_slave
	else
		redis_slave $slaveof_ip $slaveof_port
	fi
	;;
	*)
	redis_help	
	;;
esac

rm -rf redis-3.2.9
#cat -v install.sh  | tr -d '^M'  > 111.sh
