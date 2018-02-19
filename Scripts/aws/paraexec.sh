#!/bin/bash
# This script wraps the parallel-ssh command and enables it to accept a file with list of hostnames/ip's and control which user to use when connecting to remote machines and which user the commands should be run from.
# Script by Itai Ganot 2018, lel@lel.bz

TIMEOUT="5"
SESSIONS="8"

OSTYPE=$(cat /etc/*release | awk 'NR==1')
if [[ $OSTYPE =~ "DIST" ]]; then
    OS="Ubuntu"
else
    OS="CentOS"
fi

PSSHBIN=$(which parallel-ssh)
if [[ ! $? -eq "0" ]]; then
    case OS in
    Ubuntu)
	sudo apt install pssh -y
	PSSHBIN=$(which parallel-ssh)
    ;;
    CentOS)
	sudo yum install pssh -y
	PSSHBIN=$(which parallel-ssh)
    ;;
    *)
	echo "Unknown operating system and parallel-ssh is not installed, please install manually"
	exit 1
    ;;
    esac
fi

function usage {
echo "Usage: $(basename $0) [OPTIONS] [COMMAND/s]"
echo "Examples:"
echo "$(basename $0) -l server.list -c uname -a"
echo "$(basename $0) -l server.list -r -u itaig -c uname -a"
echo ""
echo "Options:"
echo "   -l                     :     Provide list containing hostnames/ips"
echo "   -c                     :     Command/s to run"
echo "   -u username [optional] :     Run commands remotely as supplied user"
echo "   -r [optional]          :     Connect to remote machine as user root"
echo ""
}

while getopts ":l:c:u:r" opt; do
	case $opt in
		l)
			LIST=$OPTARG
		;;
		u)
			USER=$OPTARG
			USERSWITCH="-l $USER"
		;;
		r)
			RUSER=true
			RUSERSWITCH="-l root"
			RUSERCMD="su - $USER -c "
		;;
		c)
			shift "$((OPTIND-2))"
			COMMANDS=$(IFS=' '; printf "%s" "$*")
		;;
		*)
			usage
			exit 1
		;;
	esac
done

if [[ -z $LIST ]] || [[ -z $COMMANDS ]]; then
	echo "Error - not enough arguments have been supplied"
	usage
fi

if [[ -z $USER ]]; then
	echo "User not supplied, using current user"
	$PSSHBIN -i -p $SESSIONS -t 100000000 -x "-oStrictHostKeyChecking=no" -O ConnectTimeout=$TIMEOUT -h $LIST "${COMMANDS}"
elif [[ ! -z $USER ]] && [[ ! -z $RUSER ]]; then
	echo "Connecting as root, running as user $USER"
	$PSSHBIN $RUSERSWITCH -i -p $SESSIONS -t 100000000 -x "-oStrictHostKeyChecking=no" -O ConnectTimeout=$TIMEOUT -h $LIST "su - $USER -c \"${COMMANDS}\""
elif [[ ! -z $USER ]] && [[ -z $RUSER ]]; then
	echo "Connecting to remote machine with user: $USER and executing commands"
	$PSSHBIN $USERSWITCH -i -p $SESSIONS -t 100000000 -x "-oStrictHostKeyChecking=no" -O ConnectTimeout=$TIMEOUT -h $LIST ${RUSERCMD} "${COMMANDS}"
fi

unset USER
