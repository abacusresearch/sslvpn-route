#!/usr/bin/env bash

################################################################################################
#
# version: 1.0.0
#
# author: benjamin.rechsteiner@abacus.ch
#
# changelog:
#
# - 2022-03-22 first release
#
################################################################################################

#global script variable
ME=$(basename "${0}")
SYSLOG=false
RED='\033[0;31m'
NC='\033[0m'

function usage {
	echo "Usage: ${ME} <IP or Hostname>" >&2
	echo >&2
	echo "-h) displays this help" >&2
	echo "-v) be more verbose (includes debug output)" >&2
	echo >&2
}

function cleanup {
	set +u
	set +e
	set +f
	set +o pipefail
	unset IFS
	exitCode=$1
	if [[ "${exitCode}" != "0" ]]; then	
		echo -e "${RED}ERROR${NC}: Aborting"
	fi
	trap - SIGINT SIGTERM EXIT
	exit "${exitCode}"
}

function initialize {
	trap "cleanup 2" SIGINT SIGTERM EXIT
	set -e
	set -u
	set -o pipefail
}

function parseOpts {
	customer=
	file=
	verbose=false
	while getopts hv opts
		do
		case ${opts} in
			v) verbose=true
			;;
			h) usage; exit 0
			;;
			*) usage; exit 1
			;;
		esac
	done
	dest="${@: -1}"
	if [[ -z "${dest}" ]]; then
		usage; exit 1
	fi
	if ! command -v dig &> /dev/null
	then
			error 'dig could not be found, please install dnsutils'
			exit 1
	fi
	if ! command -v sudo &> /dev/null
	then
			error 'sudo could not be found, please install sudo'
			exit 1
	fi
}

function log {
	local msg="${1}"
	local log_out="${2}"

	if ${SYSLOG}; then
		logger -i -t "${me}" "${msg}"
	fi

	case ${log_out} in
		STDOUT)
			echo -e "${msg}" 
		;;
		STDERR)
			echo -e "${msg}" >&2
		;;
		*)
			echo -e "${msg}" >&2
		;;
	esac
}

function debug {
	if ${verbose}; then
		log "DEBUG: ${1}" 'STDOUT'
	fi
}

function error {
	log "${RED}ERROR${NC}: ${1}" 'STDERR'
}

function getIps {
	if [[ ${dest} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
		ips=("${dest}")
	elif [[ ${dest} =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$ ]]; then
		local dns=$(dig +short "${dest}" | grep -v '\.$' | xargs)
		ips=($dns)
	else
		error 'Destination argument is not a valide IP or Hostname'
		cleanup 1
	fi
	declare -a ips
	if ((${#ips[@]})); then
		error 'No IP could be resolved for this hostname'
		cleanup 1
	fi
}

function getGwIp {
	gwip=$(netstat -nr | grep 46.227.224 | awk '{ print $2 }')
	if [[ ${gwip} == '0.0.0.0' ]]; then
		error 'Cannot identify the gateway IP - please contact your IT-Helpdesk'
		cleanup 1
	fi
}

function setRoute {
	for ip in "${ips[@]}"; do
		ip_route="${ip}/32"
		if command -v ip &> /dev/null; then
			debug 'Get sudo permission to set the IP route'
			sudo ip route add ${ip_route} dev ppp0
			debug "Set ip route ${ip_route} through SSLVPN"
		elif command -v netstat &> /dev/null; then
			getGwIp
			debug 'Get sudo permission to set the IP route'
			sudo route add ${ip_route} ${gwip}
			debug "Set ip route ${ip_route} through SSLVPN"
		else
			error 'Please install iproute2 or net-tools'
			cleanup 1
		fi
	done
}

function main {
	getIps
	setRoute
}

parseOpts "$@"
initialize
main
cleanup 0
