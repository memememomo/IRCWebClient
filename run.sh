#!/bin/bash

prog=logs
lockfile=./myserver_lock
start_server=/home/admin2/perl5/perlbrew/perls/perl-5.14.2/bin/start_server
plackup=/home/admin2/perl5/perlbrew/perls/perl-5.14.2/bin/plackup
psgifile=./irc_client.pl
interval=2
pid=./pid.txt
port=20003

RETVAL=0

start() {
    if [ -f $lockfile ]; then
	echo "$prog is started...";
	return 1;
    fi

    echo -n "Starting $prog: "
    $start_server --interval=$interval -- $plackup -s Twiggy --port=$port $psgifile &
    RETVAL=$?
    echo
    [ $RETVAL = 0 ] && touch ${lockfile}
    return $RETVAL;
}


reload() {
    echo -n $"Reloading $prog: "
    id=`ps ax | grep $start_server | awk '{print $1}'`
    kill -HUP $id
    RETVAL=$?
    echo
    [ $RETVAL = 0 ]
    return $RETVAL
}


stop() {
    echo -n $"Stopping $prog: "
    id=`ps ax | grep $start_server | awk '{print $1}'`
    kill -TERM $id
    RETVAL=$?
    echo
    [ $RETVAL = 0 ] && rm -f ${lockfile}
    return $RETVAL;
}


case "$1" in
    start)
	start
	;;
    stop)
	stop
	;;
    reload)
	reload
	;;
    *)
	echo $"Usage: $prog {start|stop|reload}"
	exit 1
esac

exit $RETVAL
