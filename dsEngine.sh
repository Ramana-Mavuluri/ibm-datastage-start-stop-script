#!/bin/bash

# Simple shell script to start and stop ds engine
# Version: 1.0
# Date: 14/10/2013
# Author: Francesco Pitzalis
# Mail: francescopitz gmail com

# This function chech if a process passed as first parameter is still running and ask for termination
check_process() {
	local LN=`ps -ef | grep -i $1 | grep -v grep | wc -l`
        if [ "$LN" -gt 0 ]; then
                echo "Warning: there is probably someone still using DataStage, wait for the users to stop their processes."
                `ps -ef | grep -i phantom | grep -v grep`
                echo "Do you want to kill this process? [y/n] "
                read ANSWER
                # Putting a regex in a variable is a workaround for compatibility with old bash versions (3.1 and previous)
                REGEX="^[nNyY]$"
                while ! [[ $ANSWER =~ $REGEX ]]
                do
                        echo "Reply with 'y' or 'n' please. Do you want to kill this process? [y/n] "
                        read ANSWER
                done
                case $ANSWER in
                y|Y)
                        kill -9 `ps -ef | grep -i $1 | sed "s/\s\s*/ /g" | cut -f2 -d ' '`
                        ;;
                n|N)
                        echo "DataStage Engine not stopped!"
                        exit 1
                        ;;
                esac
	fi
}

# Simple function that controls if a path exists, is a regular file and is executable
check_executable() {
	if [ ! -e $1 ]; then
		echo "ERROR: $1 is required but doesn't exist"
		exit -3 
	else
		if [ ! -f $1 ]; then
			echo "ERROR: $1 isn't a regular file."
			exit -3 
		else
			if [ ! -x $1 ]; then
				echo "ERROR: $1 isn't executable."
				exit -3 
			fi
		fi
	fi
}

# Function that shows usage instructions and exits
usage() {
	echo "Usage: dsEngine.sh [-dshome path_to_dshome] -start|-stop|-restart"
	exit -1 
}

case $# in
1)
	DSHOME="/opt/IBM/InformationServer/Server/DSEngine"
	COMMAND=$1
	;;
3)
	case $1 in
	-dshome)
		DSHOME=`readlink -m $2`
		if [ ! -d $DSHOME ]; then
			echo "$DSHOME is not a directory. Program abort."
			exit -3 
		else
			check_executable "$DSHOME/dsenv"
			check_executable "$DSHOME/bin/uv"
		fi
		;;
	*)
		usage
		;;
	esac
	COMMAND=$3
	;;
*)
	usage
	;;
esac

case $COMMAND in
-start)	
	if [ `netstat -a | grep dsrpc | wc -l` -gt 0 ]; then
		echo "DataStage engine is already running. No need to start it."
	else
		ACTUAL_DIRECTORY=`pwd`
                cd $DSHOME
                . ./dsenv
                bin/uv -admin -start
                cd $ACTUAL_DIRECTORY
		if [ `netstat -a | grep dsrpc | wc -l` -gt 0 ]; then
			echo "DataStage engine successfully started."
		else
			echo "Something has gone wrong... DataStage engine is still up!"
                        exit -2
		fi
	fi
	;;
-stop)
	if [ `netstat -a | grep dsrpc | wc -l` -eq 0 ]; then
		echo "DataStage engine is already not running. No need to stop it."
	else
		check_process phantom
		check_process dsapi
		check_process dscs
		DSRPC_CONN=`netstat -a | grep dsrpc | wc -l`
		if [ $DSRPC_CONN -gt 1 ]; then
			echo "There are still some connections. You need to wait or reboot the machine."
			exit 2
		else
			DSRPC_STATUS=`netstat -a | grep dsrpc | sed "s/\s\s*/ /g" | cut -f6 -d ' ' | grep -i listen | wc -l`
			if [ $DSRPC_STATUS -lt 1 ]; then
				echo "There are still some connections. You need to wait or reboot the machine."
				exit 2
			fi
		fi
		ACTUAL_DIRECTORY=`pwd`
		cd $DSHOME
		. ./dsenv
		bin/uv -admin -stop
		cd $ACTUAL_DIRECTORY
		if [ `netstat -a | grep dsrpc | wc -l` -eq 0 ]; then
			echo "DataStage engine successfully stopped."
		else
			echo "Something has gone wrong... DataStage engine is still up!"
			exit -2
		fi
	fi
;;
-restart)
	$0 -stop
	$0 -start
	;;
*)
	echo "Usage: $0 [-dshome path_to_dshome] -start|-stop|-restart"
	exit -1
	;;
esac
exit 0
