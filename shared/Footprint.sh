#!/bin/sh
CONF="/etc/config/qpkg.conf"
QPKG_NAME="Footprint"

QPKG_ROOT=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f "${CONF}")
APACHE_ROOT=$(/sbin/getcfg SHARE_DEF defWeb -d Qweb -f /etc/config/def_share.info)
QHTTP_ROOT="/home/Qhttpd/${APACHE_ROOT}"

PID_FILE="/tmp/footprint.pid"
STOP_FILE="/tmp/footprint-stop"

export QNAP_QPKG=${QPKG_NAME}

echo "Footprint [$(date)]: $0 $1 root=${QPKG_ROOT}, apacheRoot=${APACHE_ROOT}" >> /tmp/footprint.log

case "$1" in
  start)
    ENABLED=$(/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f "${CONF}")
    if [[ "${ENABLED}" != "TRUE" ]]; then
        echo "${QPKG_NAME} is disabled."
        exit 1
    fi

    chmod +x "${QPKG_ROOT}/scripts/footprint-daemon.sh"
    chmod +x "${QPKG_ROOT}/scripts/scan.sh"

    if [[ ! -h "${QHTTP_ROOT}/footprint" ]]; then
        ln -s "${QPKG_ROOT}/web" "${QHTTP_ROOT}/footprint"
    fi

    rm "${STOP_FILE}" || true

    if [[ ! -f "${PID_FILE}" ]]; then
        #nohup "${QPKG_ROOT}/scripts/footprint-daemon.sh" > /tmp/footprint-daemon.log &
        "${QPKG_ROOT}/scripts/footprint-daemon.sh" > /tmp/footprint-daemon.log &
        echo $! > "${PID_FILE}"
    fi
    ;;

  stop)
    rm "${QHTTP_ROOT}/footprint" || true

    echo -n "Stopping daemon "
    touch "${STOP_FILE}"
    #i=0
    #while "$(ps | grep -E "^$(cat ${PID_FILE})")"; do
    #    i=$(expr ${i} + 1)
    #    if [[ ${i} -gt 10 ]]; then
    #        #kill -9 $(cat ${PID_FILE})
    #        echo -n ""
    #    else
    #        echo -n "."
    #        sleep 1
    #    fi
    #done
    #echo " stopped"

    rm "${PID_FILE}" || true
    ;;

  restart)
    $0 stop
    $0 start
    ;;

  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac

exit 0