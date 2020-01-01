#!/usr/bin/env bash
[ -z "$DEBUG" ] || set -x
export LC_ALL=C

PROGRAM=${PROGRAM:-$(basename "${BASH_SOURCE[0]}")}
PROGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAM_OPTS=$@
if [ -z "${PREFIX}" ]
then
  PROGRAM_LOGDIR="${PROGRAM_LOGDIR:-/var/log/betterclone}"
  PROGRAM_CFGD="${PROGRAM_CFGD:-/etc/betterclone}"
  HTTP_API_ROUTES="${HTTP_API_ROUTES:-/usr/local/lib/betterclone/hooks.json}"
  HTTP_API="${HTTP_API:-/usr/local/lib/betterclone/betterclone-wrapper-api.sh}"
  WEBHOOK_HTTP_API="${WEBHOOK_HTTP_API:-/usr/local/lib/betterclone/webhook}"
else
  PROGRAM_LOGDIR="${PROGRAM_LOGDIR:-${PREFIX}/log}"
  PROGRAM_CFGD="${PROGRAM_CFGD:-${PREFIX}/etc}"
  HTTP_API_ROUTES="${HTTP_API_ROUTES:-${PREFIX}/lib/hooks.json}"
  HTTP_API="${HTTP_API:-${PREFIX}/lib/betterclone-wrapper-api.sh}"
  WEBHOOK_HTTP_API="${WEBHOOK_HTTP_API:-${PREFIX}/lib/webhook}"
fi
PROGRAM_LOG="${PROGRAM_LOG:-$PROGRAM_LOGDIR/betterclone-api.log}"
source "${PROGRAM_CFGD}/config.env"
export TOKEN="${API_TOKEN}"
export RUN="${HTTP_API}"


usage() {
    cat <<EOF
Usage:
    $PROGRAM [-h] [-p <port>]

This program launches a HTTP WEB API for betterclone. Configuration
settings are defined by environment variables or in "${PROGRAM_CFGD}/config.env"

Options
  -p <port>   Por where WEB API will be listen

(c) Jose Riguera Lopez 2018 <jriguera@gmail.com>

EOF
}


die() {
    { cat <<< "$@" 1>&2; }
    exit 1
}


run() {
    exec ${WEBHOOK_HTTP_API} -hooks "${HTTP_API_ROUTES}" -template -verbose -ip ${API_HOST} -port ${API_PORT} -urlprefix "" 2>&1 | tee -a "${PROGRAM_LOG}"
}


if [ "${0}" == "${BASH_SOURCE[0]}" ]
then
    # PORT=
    # Parse main options
    while getopts ":hp:" opt
    do
        case "${opt}" in
            h)
                usage
                exit 0
            ;;
            p)
                API_PORT="${OPTARG}"
            ;;
            :)
                die "Option -${OPTARG} requires an argument"
            ;;
        esac
    done
    run
fi

