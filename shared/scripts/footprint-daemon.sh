#!/usr/bin/env bash

CONF="/etc/config/qpkg.conf"
QPKG_NAME="Footprint"

ROOT_PATH=$(/sbin/getcfg ${QPKG_NAME} Install_Path -f "${CONF}")
SHARE_PREFIX="/share"
FOOTPRINT_DIR=".footprint"

DELAY_FILE="/etc/config/footprint.delay"
LIST_FILE="/etc/config/footprint.list"
PROPOSAL_FILE="/etc/config/footprint.list.proposal"
REMOVAL_FILE="/etc/config/footprint.list.removal"
STOP_FILE="/tmp/footprint-stop"
SCAN_FILE="/${FOOTPRINT_DIR}/scannow"

LAST_SCAN=$(date +%s)
DELAY=$(cat "${DELAY_FILE}" 2> /dev/null);

echo -n "[$(date "+%Y-%m-%d %H:%M:%S")] Root: ${ROOT_PATH}, delay: ${DELAY}"
if [[ -z ${DELAY} ]]; then
  DELAY=86400
  echo "${DELAY}ms (default)"
else
  echo "ms"
fi

function checkStop() {
  if [[ -f "${STOP_FILE}" ]]; then
    echo "File ${STOP_FILE} exists: stopping..."
    exit 0
  fi
}

while true; do
  checkStop

  NOW=$(date +%s)
  SINCE_LAST=$((NOW - LAST_SCAN))

  if [[ -f "${PROPOSAL_FILE}" ]]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Adding files from ${PROPOSAL_FILE}..."
    mv "${PROPOSAL_FILE}" "${PROPOSAL_FILE}.tmp"
    cat "${PROPOSAL_FILE}.tmp" "${LIST_FILE}" | sort | uniq > "/tmp/$(basename "${LIST_FILE}").tmp"
    mv "/tmp/$(basename "${LIST_FILE}").tmp" "${LIST_FILE}"
    rm "${PROPOSAL_FILE}.tmp"
  fi

  if [[ -f "${REMOVAL_FILE}" ]]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Removing files from ${REMOVAL_FILE}..."
    mv "${REMOVAL_FILE}" "${REMOVAL_FILE}.tmp"
    cp "${LIST_FILE}" "/tmp/$(basename "${LIST_FILE}").tmp"
    while IFS= read folder; do
      grep -v "${folder}|" "/tmp/$(basename "${LIST_FILE}").tmp" > "/tmp/$(basename "${LIST_FILE}").tmp2"
      mv "/tmp/$(basename "${LIST_FILE}").tmp2" "/tmp/$(basename "${LIST_FILE}").tmp"
    done < "${REMOVAL_FILE}.tmp"
    mv "/tmp/$(basename "${LIST_FILE}").tmp" "${LIST_FILE}"
    rm "${REMOVAL_FILE}.tmp"
  fi

  while IFS= read folder; do
    if [[ ! -d "${SHARE_PREFIX}${folder}/.footprint" ]]; then
      mkdir -p "${SHARE_PREFIX}${folder}/.footprint"
      chmod a+rw "${SHARE_PREFIX}${folder}/.footprint"
      echo "[$(date "+%Y-%m-%d %H:%M:%S")] ${SHARE_PREFIX}${folder}/.footprint created"
    fi
  done < "${LIST_FILE}"

  # Mark folder for scan
  if [[ ${SINCE_LAST} -gt ${DELAY} ]]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Last scan: ${LAST_SCAN}, now: ${NOW}, since: ${SINCE_LAST}, delay: ${DELAY}"
    while IFS= read folder; do
      if [[ ! -f "${SHARE_PREFIX}${folder}${SCAN_FILE}" ]]; then
        touch "${SHARE_PREFIX}${folder}${SCAN_FILE}";
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ${SHARE_PREFIX}${folder}${SCAN_FILE} created"
      fi
    done < "${LIST_FILE}"
  fi

  # Scan marked folders
  cp "${LIST_FILE}" "${LIST_FILE}.processing"
  while IFS= read folder; do
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Checking ${SHARE_PREFIX}${folder}"
    checkStop
    if [[ -f "${SHARE_PREFIX}${folder}${SCAN_FILE}" ]]; then
      LAST_SCAN=${NOW} # Update before scan
      rm "${SHARE_PREFIX}${folder}${SCAN_FILE}";
      echo "[$(date "+%Y-%m-%d %H:%M:%S")] Scanning ${SHARE_PREFIX}${folder}, ${SHARE_PREFIX}${folder}${SCAN_FILE} removed"
      "${ROOT_PATH}/scripts/scan.sh" "${SHARE_PREFIX}${folder}"
    fi
    LAST_SCAN=${NOW} # Update after scan
  done < "${LIST_FILE}.processing"
  rm "${LIST_FILE}.processing"

  sleep 1
done
