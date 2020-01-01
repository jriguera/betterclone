#!/usr/bin/env bash
[ -z "$DEBUG" ] || set -x
export LC_ALL=C

if [ -z "${PREFIX}" ]
then
  PROGRAM_LOGDIR="${PROGRAM_LOGDIR:-/var/log/betterclone}"
  PROGRAM_CFGD="${PROGRAM_CFGD:-/etc/betterclone}"
  BETTERCLONE="${BETTERCLONE:-betterclone.sh}"
else
  PROGRAM_LOGDIR="${PROGRAM_LOGDIR:-${PREFIX}/log}"
  PROGRAM_CFGD="${PROGRAM_CFGD:-${PREFIX}/etc}"
  BETTERCLONE="${BETTERCLONE:-${PREFIX}/bin/betterclone.sh}"
fi
HTTP_API_SESSION_DIR="${HTTP_API_SESSION_DIR:-${PROGRAM_LOGDIR}/api-sessions}"
source "${PROGRAM_CFGD}/config.env"

ACTION=$1
shift


run_async() {
  local action="${1}"
  shift 1

  (
    local pid
    (
        export PREFIX
        exec setsid ${BETTERCLONE} ${action} ${@} > ${HTTP_API_SESSION_DIR}/$BASHPID.log 2>&1
    ) &
    pid=$!
    echo "PID=${pid} running ..."
    echo "/show?pid=$pid"
  )
  return 0
}


run_sync() {
  local action="${1}"
  shift 1

  local pid
  local rvalue
  (
      exec ${BETTERCLONE} ${action} ${@}
  )
  rvalue=$?
  if [ "${rvalue}" -ne "0" ]
  then
    echo "ERROR"
    return 1
  fi
  return 0
}


show() {
  local spid="${1}"
  local debug="${2}"

  local f
  local rvalue
  local folder
  if [ -z "${debug}" ] || [ "${debug}" -eq "0" ]
  then
    folder="${HTTP_API_SESSION_DIR}"
  else
    folder="${PROGRAM_LOGDIR}"
  fi
  if [ -z "${spid}" ] || [ "${spid}" == "last" ]
  then
    f=$(find ${folder} -maxdepth 1 -type f -name "*.log" -printf "%T@ %p\n" | sort -rn | awk '{ print $2; exit }')
    spid=$(basename "${f}")
    spid="${spid%.*}"
    (
        cat ${f} 2> /dev/null
    )
  else
    (
        cat ${folder}/${spid}.log 2> /dev/null
    )
  fi
  rvalue=$?
  if [ "${rvalue}" -ne "0" ]
  then
    echo "ERROR PID=${spid} does not exist ..."
    return 1
  fi
  return 0
}


status() {
  local spid="${1}"

  local f
  local st
  if [ -z "${spid}" ] || [ "${spid}" == "all" ]
  then
    for f in $(find ${HTTP_API_SESSION_DIR} -maxdepth 1 -type f -name "*.log" -printf "%T@ %p\n" | sort -rn | awk '{ print $2 }' | xargs)
    do
      spid=$(basename "${f}")
      spid="${spid%.*}"
      if ps -p "${spid}" >/dev/null
      then
        echo "${spid} $(cat ${f} | awk 'END{ print $1 }') Running..."
      else
        echo "${spid} $(cat ${f} | awk 'END{ print $0 }')"
      fi
    done
  else
    if ps -p "${spid}" >/dev/null
    then
      echo "${spid} $(cat ${HTTP_API_SESSION_DIR}/${spid}.log | awk 'END{ print $1 }') Running..."
    else
      if [ -r ${HTTP_API_SESSION_DIR}/${spid}.log ]
      then
        echo "${spid} $(cat ${HTTP_API_SESSION_DIR}/${spid}.log | awk 'END{ print $0 }')"
      else
        echo "ERROR PID=${spid} does not exist ..."
        return 1
      fi
    fi
  fi
  return 0
}


index() {
  echo "Trigger a backup of <mountpoint>: /backup?mountpoint=<your-mountpoint>"
  echo "Trigger a recovery of <mountpoint>: /restore?mountpoint=<your-mountpoint>"
  echo "Show the output of backup pid <pid>: /show?pid=<pid>"
  echo "List status of recent backups: : /status?pid=<pid>"
}


error() {
  local action="${1}"

  echo "Unknown action ${action}"
  echo "ERROR"
  return 1
}


manage_logs() {
  local max="${1}"

  if [ "${max}" -ne "0" ]
  then
      mkdir -p "${HTTP_API_SESSION_DIR}"
      for f in $(find "${HTTP_API_SESSION_DIR}" -maxdepth 1 -type f -name "*.log" -printf "%T@ %p\n" | sort -rn | awk -v keep=${max} '{ if (NR > keep) print $2 }' | xargs)
      do
          rm -f "${f}"
      done
  fi
}


RVALUE=0
manage_logs ${API_SESSION_MAX:-5}
case "${ACTION}" in
    backup|restore)
        run_async "${ACTION}" "${@}"
        RVALUE=$?
    ;;
    list)
        run_sync "${ACTION}" "${@}"
        RVALUE=$?
    ;;
    show)
        show "${@}"
        RVALUE=$?
    ;;
    status)
        status "${@}"
        RVALUE=$?
    ;;
    '')
        index
        RVALUE=$?
    ;;
    *)
        error "${ACTION}"
        RVALUE=$?
    ;;
esac
exit ${RVALUE}

