#!/usr/bin/env bash

if [[ -z $1 ]]; then
  echo "USAGE: ${0} DIRECTORY"
  exit 1
fi

SCAN_PATH=${1}
EXIFTOOL="/share/CACHEDEV1_DATA/.qpkg/Entware/bin/exiftool"

STOP_FILE="/tmp/footprint-stop"

FOOTPRINT_FOLDER=".footprint"
FOLDER_LIST_FILE="${SCAN_PATH}/${FOOTPRINT_FOLDER}/list"
FOLDER_CACHE_FILE="${FOOTPRINT_FOLDER}/cache"
FOLDER_STATUS_FILE="${SCAN_PATH}/${FOOTPRINT_FOLDER}/status"
FOLDER_STOP_FILE="${SCAN_PATH}/${FOOTPRINT_FOLDER}/stop"

START_TIME=$(date +%s);
CHANGED_COUNT=0;
SCANNED_COUNT=0;
PROCESSED_COUNT=0;
TOTAL_COUNT=0;
CACHED_COUNT=0;

echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";

if [[ ! -d "${SCAN_PATH}/${FOOTPRINT_FOLDER}" ]]; then
  mkdir -p "${SCAN_PATH}/${FOOTPRINT_FOLDER}"
fi

hashGet() {
    local array=${1} index=${2}
    local i="${array}_$index"
    printf '%s' "${!i}"
}

countFiles() {
  count=0;
  for path in "${1}"*; do
    if [[ -d "${path}" ]];then
      count=$((count + $(countFiles "${path}/")));
    elif [[ -f "${path}" ]]; then
      count=$((count + 1));
    fi
  done
  echo "${count}";
}

scanFile() {
  start=$(date +%s)
  file=$1
  mode=$2

  if [[ -f "${FOLDER_STOP_FILE}" || -f ${STOP_FILE} ]]; then
    rm "${FOLDER_STOP_FILE}" || true
    echo "${START_TIME}|$(date +%s)|STOPPED|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||${mode}" > "${FOLDER_STATUS_FILE}";
    exit 0
  fi

  key=$(echo "${file}" | sed -E 's/[^a-zA-Z0-9]/_/g')
  logMessage="${file}"

  if [[ ! -f "${file}" ]]; then # Remove non existing files from cache
    grep -v "declare \"list_${key}=" "${FOLDER_CACHE_FILE}" > "${FOLDER_CACHE_FILE}.tmp"
    mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
    grep -v "${file}|" "${FOLDER_LIST_FILE}" > "/tmp/$(basename "${FOLDER_LIST_FILE}").tmp"
    mv "/tmp/$(basename "${FOLDER_LIST_FILE}").tmp" "${FOLDER_LIST_FILE}"
    echo -e "\033[2K\r${logMessage} was removed (took: $(($(date +%s) - start))s)"
  else # File exists, lets proceed
    SCANNED_COUNT=$((SCANNED_COUNT + 1));
    stat=$(stat -c '%s|%W|%Y' "${file}")
    length=$(echo "${stat}" | cut -d'|' -f1)
    updatedAt=$(echo "${stat}" | cut -d'|' -f3)

    isSame=0
    foundInList=0
    if [[ -f ${FOLDER_LIST_FILE} ]]; then
      previous=$(hashGet list "${key}")
      if [[ -n ${previous} ]]; then
        foundInList=1
        lastLength=$(echo "${previous}" | cut -d'|' -f2)
        lastUpdatedAt=$(echo "${previous}" | cut -d'|' -f4)

        if [[ "${length}" = "${lastLength}" && ${updatedAt} = "${lastUpdatedAt}" ]]; then
            isSame=1
        fi
      fi
    fi

    if [[ "${foundInList}" = "${mode}" || "${mode}" = "2" ]]; then
      PROCESSED_COUNT=$((PROCESSED_COUNT + 1));
      if [[ ${isSame} = 0 ]]; then
        CHANGED_COUNT=$((CHANGED_COUNT + 1));
        CREATED_AT=$(echo "${stat}" | cut -d'|' -f2)
        if [[ ${CREATED_AT} = 'W' ]]; then
          CREATED_AT=${updatedAt}
        fi
        CHECKSUM=$(sha256sum -b "${file}" | cut -d" " -f1)
        logMessage="${logMessage} (${length} bytes @ ${updatedAt}) = ${CHECKSUM}"
        LINE="${file}|${length}|${CREATED_AT}|${updatedAt}|${CHECKSUM}"

        if [[ ${foundInList} = 1 ]]; then #
          grep -v "declare \"list_${key}=" "${FOLDER_CACHE_FILE}" > "${FOLDER_CACHE_FILE}.tmp"
          mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
          grep -v "${file}|" "${FOLDER_LIST_FILE}" > "/tmp/$(basename "${FOLDER_LIST_FILE}").tmp"
          mv "/tmp/$(basename "${FOLDER_LIST_FILE}").tmp" "${FOLDER_LIST_FILE}"
        fi
        echo "declare \"list_${key}=${LINE}\"" >> "${FOLDER_CACHE_FILE}"
        echo "${LINE}" >> "${FOLDER_LIST_FILE}"
      else
        logMessage="${logMessage} did not change"
      fi

      METADATA_FILE="${FOOTPRINT_FOLDER}/metadata/${file}.txt"
      #METADATA_FILENAME=$(basename "${METADATA_FILE}")
      #METADATA_FILENAME="${METADATA_FILENAME%.*}"
      #METADATA_FILE="$(dirname "${METADATA_FILE}")/${METADATA_FILENAME}.txt"
      if [[ ! -f "${METADATA_FILE}" || ${isSame} = 0 ]]; then
        mkdir -p "$(dirname "${METADATA_FILE}")"
        #${EXIFTOOL} "${file}" -D -G0:1:2:3:4 -f -q -t -ee -U > "${METADATA_FILE}"
        ${EXIFTOOL} "${file}" -D -G0:1:2:3:4 -q -t -fast2 > "${METADATA_FILE}"
        logMessage="${logMessage} [metadata extracted]"
      fi

      THUMBNAIL_FILE="${FOOTPRINT_FOLDER}/thumbnails/${file}"
      if [[ ! -f "${THUMBNAIL_FILE}" || ${isSame} = 0 ]]; then
        mkdir -p "$(dirname "${THUMBNAIL_FILE}")"
        ffmpeg -i "${file}" -vframes 1 -an -vf "scale=500:-1" -y "${FOOTPRINT_FOLDER}/thumbnails/${file}" &> /dev/null
        logMessage="${logMessage} [thumbnail generated]"
      fi

      echo "${START_TIME}|$(date +%s)|SCANNING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}|${file}|${mode}" > "${FOLDER_STATUS_FILE}";
      if [[ ${isSame} = 0 ]]; then
        if [[ ${foundInList} = 0 ]]; then
          echo -e "\033[2K\r[NEW] ${logMessage} (took: $(($(date +%s) - start))s)"
        else
          echo -e "\033[2K\r[CHANGED] ${logMessage} (took: $(($(date +%s) - start))s)"
        fi
      else
        echo -ne "\033[2K\r${logMessage} (took: $(($(date +%s) - start))s)"
      fi
    else
      echo "${START_TIME}|$(date +%s)|SCANNING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}|${file}|${mode}" > "${FOLDER_STATUS_FILE}";
      echo -ne "\033[2K\r${logMessage} skipping (took: $(($(date +%s) - start))s)"
    fi
  fi
}

scanDirectory() {
  mode=$2 # 0: foundInList == 0, 1: foundInList == 1, 2: all files
  for filePath in "${1}"*; do
    fileName="$(basename "${filePath}")"
    if [[ "${fileName:0:1}" != "@" && "${fileName:0:1}" != "." ]]; then
      if [[ -d "${filePath}" ]];then
        scanDirectory "${filePath}/" "${mode}"
      elif [[ -f "${filePath}" ]]; then
        scanFile "${filePath}" "${mode}"
      fi
    fi
  done
  #${EXIFTOOL} . -r -D -G0:1:2:3:4 -f -ee --ext THM --ext LRV --SRT -U -w "${FOOTPRINT_FOLDER}/metadata/%d%f.txt"
}

scanCache() {
    #OLDIFS=${IFS}
    cp "${FOLDER_CACHE_FILE}" "${FOLDER_CACHE_FILE}.work"
    while read -r lineInFile; do
        filePath="$(cat "${FOLDER_CACHE_FILE}" | grep "${lineInFile}" | sed -E 's/^[^=]+=([^"]+)"$/\1/g' | cut -d'|' -f1)"
        #filePath="$(echo ${lineInFile} | sed -E 's/^[^=]+=([^"]+)"$/\1/g' | cut -d'|' -f1)"
        scanFile "${filePath}" 1
    done < "${FOLDER_CACHE_FILE}.work"
    rm "${FOLDER_CACHE_FILE}.work"
    #IFS=${OLDIFS}
}

CURRENT_DIRECTORY=$(pwd)
cd "${SCAN_PATH}" || exit 1

##CACHE_ROTTEN=0
##if [[ -f "${FOLDER_CACHE_FILE}" ]]; then
##  AGE=$(($(date +%s) - $(stat -c '%Y' "${FOLDER_CACHE_FILE}")))
##  if [[ ${AGE} -lt 7776000 ]]; then # 3 months
##    CACHE_ROTTEN=0
##  fi
##fi
##
##if [[ ! -f "${FOLDER_CACHE_FILE}" || ${CACHE_ROTTEN} = 1 ]]; then
##  #echo "Building cache"
##  rm "${FOLDER_CACHE_FILE}"
##  index=0
##  COUNT="$(wc -l "${FOLDER_LIST_FILE}" | cut -d" " -f1)"
##  while IFS= read -r line
##  do
##    key=$(echo "${line}" | cut -d"|" -f1 | sed -E 's/[^a-zA-Z0-9]/_/g')
##    index=$((index + 1))
##    echo -ne "\033[2K\rBuilding cache ${index}/${COUNT} ($((index * 100 / COUNT))%)"
##    echo "declare \"list_${key}=${line}\"" >> "${FOLDER_CACHE_FILE}"
##  done < "${FOLDER_LIST_FILE}"
##  echo "\033[2K\rCache build"
##fi

echo -n "Counting files in ${SCAN_PATH} ..."
TOTAL_COUNT=$(countFiles)
echo -e "\033[2K\rTotal files in ${SCAN_PATH}: ${TOTAL_COUNT}"
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||0" > "${FOLDER_STATUS_FILE}";

echo -n "Loading cache..."
cat "${FOLDER_CACHE_FILE}" | sort -u > "${FOLDER_CACHE_FILE}.tmp"
mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
. "${FOLDER_CACHE_FILE}"
CACHED_COUNT=$(cat "${FOLDER_CACHE_FILE}" | wc -l)
echo -e "\033[2K\rCache loaded"
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||0" > "${FOLDER_STATUS_FILE}";

scanDirectory "" 0 # new files
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||1" > "${FOLDER_STATUS_FILE}";
#scanDirectory "" 1 # check/update existing
scanCache
echo -e "\033[2K\rScanning finished"

echo "${START_TIME}|$(date +%s)|ARCHIVING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";
echo -n "Creating archives..."
tar -czf .footprint/thumbnails.tar.gz.tmp -C .footprint/thumbnails .
mv .footprint/thumbnails.tar.gz.tmp .footprint/thumbnails.tar.gz
tar -czf .footprint/metadata.tar.gz.tmp -C .footprint/metadata .
mv .footprint/metadata.tar.gz.tmp .footprint/metadata.tar.gz
echo -e "\033[2K\rArchives created"

cd "${CURRENT_DIRECTORY}" || exit 1
echo "${START_TIME}|$(date +%s)|FINISHED|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";
echo "Finished"
