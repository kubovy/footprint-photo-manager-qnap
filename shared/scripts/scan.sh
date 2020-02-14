#!/usr/bin/env bash

if [[ -z $1 ]]; then
  echo "USAGE: ${0} DIRECTORY"
  exit 1
fi

SCAN_PATH=${1}
EXIFTOOL="/share/CACHEDEV1_DATA/.qpkg/Entware/bin/exiftool"

STOP_FILE="/tmp/footprint-stop"

FOOTPRINT_PATH="${SCAN_PATH}/.footprint"
FOLDER_LIST_FILE="${FOOTPRINT_PATH}/list"
FOLDER_LIST_PROCESSING_FILE="${FOLDER_LIST_FILE}.processing"
FOLDER_CACHE_FILE="${FOOTPRINT_PATH}/cache"
FOLDER_STATUS_FILE="${FOOTPRINT_PATH}/status"
FOLDER_STOP_FILE="${FOOTPRINT_PATH}/stop"

START_TIME=$(date +%s);
CHANGED_COUNT=0;
SCANNED_COUNT=0;
PROCESSED_COUNT=0;
TOTAL_COUNT=0;
CACHED_COUNT=0;

echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";

if [[ ! -d "${FOOTPRINT_PATH}" ]]; then
  mkdir -p "${FOOTPRINT_PATH}"
fi

hashGet() {
    local array=${1} index=${2}
    local i="${array}_$index"
    printf '%s' "${!i}"
}

isRelevant() {
  file=$1
  ext=$(echo "${file##*.}" | awk '{print tolower($0)}')
  if [[ ${ext} = "bmp"\
        || ${ext} = "exif"\
        || ${ext} = "gif"\
        || ${ext} = "jpg" || ${ext} = "jpeg" || ${ext} = "jp2" || ${ext} = "jpx"\
        || ${ext} = "png"\
        || ${ext} = "3fr"\
        || ${ext} = "ari"\
        || ${ext} = "arw" || ${ext} = "srf" || ${ext} = "sr2"\
        || ${ext} = "bay"\
        || ${ext} = "braw"\
        || ${ext} = "cri"\
        || ${ext} = "crw" || ${ext} = "cr2" || ${ext} = "cr3"\
        || ${ext} = "cap" || ${ext} = "iiq" || ${ext} = "eip"\
        || ${ext} = "dcs" || ${ext} = "dcr" || ${ext} = "drf" || ${ext} = "k25" || ${ext} = "kdc"\
        || ${ext} = "dng"\
        || ${ext} = "erf"\
        || ${ext} = "fff"\
        || ${ext} = "gpr"\
        || ${ext} = "mef"\
        || ${ext} = "mdc"\
        || ${ext} = "mos"\
        || ${ext} = "mrw"\
        || ${ext} = "nef" || ${ext} = "nrw"\
        || ${ext} = "orf"\
        || ${ext} = "pet" || ${ext} = "ptx"\
        || ${ext} = "pxn"\
        || ${ext} = "r3d"\
        || ${ext} = "raf"\
        || ${ext} = "raw" || ${ext} = "rw2"\
        || ${ext} = "rwl"\
        || ${ext} = "rwz"\
        || ${ext} = "srw"\
        || ${ext} = "x3f"\
        || ${ext} = "3gp" || ${ext} = "3g2"\
        || ${ext} = "asf"\
        || ${ext} = "amv"\
        || ${ext} = "avi"\
        || ${ext} = "drc"\
        || ${ext} = "flv" || ${ext} = "f4v" || ${ext} = "f4p" || ${ext} = "f4a" || ${ext} = "f4b"\
        || ${ext} = "mkv"\
        || ${ext} = "mpg" || ${ext} = "mp2" || ${ext} = "mpeg" || ${ext} = "mpe" || ${ext} = "mpv" || ${ext} = "m2v"\
        || ${ext} = "mp4" || ${ext} = "m4p" || ${ext} = "m4v"\
        || ${ext} = "mxf"\
        || ${ext} = "nsv"\
        || ${ext} = "roq"\
        || ${ext} = "rm" || ${ext} = "rmvb"\
        || ${ext} = "svi"\
        || ${ext} = "vob" || ${ext} = "ogv" || ${ext} = "ogg"\
        || ${ext} = "webm"\
        || ${ext} = "wmv"\
        || ${ext} = "yuv" ]]; then
    return 0 # True
  else
    return 1 # False
  fi
}

countFiles() {
  count=0;
  for path in "${1}"*; do
    if [[ -f "${FOLDER_STOP_FILE}" || -f ${STOP_FILE} ]]; then
      rm "${FOLDER_STOP_FILE}" || true
      echo "${START_TIME}|$(date +%s)|STOPPED|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";
      exit 0
    fi
    if [[ -d "${path}" ]];then
      count=$((count + $(countFiles "${path}/")));
    elif [[ -f "${path}" ]]; then
      if isRelevant "${path}"; then
        count=$((count + 1));
      fi
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
  logMessage="${SCAN_PATH}/${file}"

  if [[ ! -f "${file}" ]]; then # Remove non existing files from cache
    grep -v "declare \"list_${key}=" "${FOLDER_CACHE_FILE}" > "${FOLDER_CACHE_FILE}.tmp"
    mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
    grep -v "${file}|" "${FOLDER_LIST_PROCESSING_FILE}" > "${FOLDER_LIST_PROCESSING_FILE}.tmp"
    mv "${FOLDER_LIST_PROCESSING_FILE}.tmp" "${FOLDER_LIST_PROCESSING_FILE}"
    echo -e "\033[2K\r${logMessage} was removed (took: $(($(date +%s) - start))s)"
  elif ! isRelevant "${file}"; then
    grep -v "declare \"list_${key}=" "${FOLDER_CACHE_FILE}" > "${FOLDER_CACHE_FILE}.tmp"
    mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
    grep -v "${file}|" "${FOLDER_LIST_PROCESSING_FILE}" > "${FOLDER_LIST_PROCESSING_FILE}.tmp"
    mv "${FOLDER_LIST_PROCESSING_FILE}.tmp" "${FOLDER_LIST_PROCESSING_FILE}"
    echo -e "\033[2K\r${logMessage} not relevant (took: $(($(date +%s) - start))s)"
  else # File exists and is relevant, lets proceed
    SCANNED_COUNT=$((SCANNED_COUNT + 1));
    stat=$(stat -c '%s|%W|%Y' "${file}")
    length=$(echo "${stat}" | cut -d'|' -f1)
    updatedAt=$(echo "${stat}" | cut -d'|' -f3)

    isSame=0
    foundInList=0
    if [[ -f ${FOLDER_LIST_PROCESSING_FILE} ]]; then
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
          grep -v "${file}|" "${FOLDER_LIST_PROCESSING_FILE}" > "${FOLDER_LIST_PROCESSING_FILE}.tmp"
          mv "${FOLDER_LIST_PROCESSING_FILE}.tmp" "${FOLDER_LIST_PROCESSING_FILE}"
        fi
        echo "declare \"list_${key}=${LINE}\"" >> "${FOLDER_CACHE_FILE}"
        echo "${LINE}" >> "${FOLDER_LIST_PROCESSING_FILE}"
      else
        logMessage="${logMessage} did not change"
      fi

      METADATA_FILE="${FOOTPRINT_PATH}/metadata/${file}.txt"
      #METADATA_FILENAME=$(basename "${METADATA_FILE}")
      #METADATA_FILENAME="${METADATA_FILENAME%.*}"
      #METADATA_FILE="$(dirname "${METADATA_FILE}")/${METADATA_FILENAME}.txt"
      if [[ ! -f "${METADATA_FILE}" || ${isSame} = 0 ]]; then
        mkdir -p "$(dirname "${METADATA_FILE}")"
        #${EXIFTOOL} "${file}" -D -G0:1:2:3:4 -f -q -t -ee -U > "${METADATA_FILE}"
        ${EXIFTOOL} "${file}" -D -G0:1:2:3:4 -q -t -fast2 > "${METADATA_FILE}"
        logMessage="${logMessage} [metadata extracted]"
      fi

      THUMBNAIL_FILE="${FOOTPRINT_PATH}/thumbnails/${file}"
      if [[ ! -f "${THUMBNAIL_FILE}" || ${isSame} = 0 ]]; then
        mkdir -p "$(dirname "${THUMBNAIL_FILE}")"
        ffmpeg -i "${file}" -vframes 1 -an -vf "scale=500:-1" -y "${FOOTPRINT_PATH}/thumbnails/${file}" &> /dev/null
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
        if isRelevant "${filePath}"; then
            scanFile "${filePath}" "${mode}"
        fi
      fi
    fi
  done
  #${EXIFTOOL} . -r -D -G0:1:2:3:4 -f -ee --ext THM --ext LRV --SRT -U -w "${FOOTPRINT_FOLDER}/metadata/%d%f.txt"
}

scanCache() {
    while IFS= read -r lineInFile; do
        filePath="$(cat "${FOLDER_CACHE_FILE}" | grep "${lineInFile}" | sed -E 's/^[^=]+=([^"]+)"$/\1/g' | cut -d'|' -f1)"
        # Scan including irrelevant files from cache, they will be sorted out later
        scanFile "${filePath}" 1
    done < "${FOLDER_CACHE_FILE}.work"
    rm "${FOLDER_CACHE_FILE}.work"
}

CURRENT_DIRECTORY=$(pwd)
cd "${SCAN_PATH}" || exit 1

echo -n "Counting files in ${SCAN_PATH} ..."
TOTAL_COUNT=$(countFiles)
echo -e "\033[2K\rTotal files in ${SCAN_PATH}: ${TOTAL_COUNT}"
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||0" > "${FOLDER_STATUS_FILE}";

if [[ -f "${FOLDER_LIST_FILE}" ]]; then
  cp ${FOLDER_LIST_FILE} "${FOLDER_LIST_PROCESSING_FILE}"
fi

echo -n "Loading cache..."
cat "${FOLDER_CACHE_FILE}" | sort -u > "${FOLDER_CACHE_FILE}.tmp"
mv "${FOLDER_CACHE_FILE}.tmp" "${FOLDER_CACHE_FILE}"
. "${FOLDER_CACHE_FILE}"
CACHED_COUNT=$(cat "${FOLDER_CACHE_FILE}" | wc -l)
echo -e "\033[2K\rCache loaded"
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||0" > "${FOLDER_STATUS_FILE}";

cp "${FOLDER_CACHE_FILE}" "${FOLDER_CACHE_FILE}.work"
scanDirectory "" 0 # new files
echo "${START_TIME}|$(date +%s)|PREPARING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||1" > "${FOLDER_STATUS_FILE}";
#scanDirectory "" 1 # check/update existing
scanCache
mv ${FOLDER_LIST_PROCESSING_FILE} "${FOLDER_LIST_FILE}"
echo -e "\033[2K\rScanning finished"

echo "${START_TIME}|$(date +%s)|ARCHIVING|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";
echo -n "Creating archives..."
tar -czf "${SCAN_PATH}/.footprint/thumbnails.tar.gz.tmp" -C "${SCAN_PATH}/.footprint/thumbnails" .
mv "${SCAN_PATH}/.footprint/thumbnails.tar.gz.tmp" "${SCAN_PATH}/.footprint/thumbnails.tar.gz"
tar -czf "${SCAN_PATH}/.footprint/metadata.tar.gz.tmp" -C "${SCAN_PATH}/.footprint/metadata" .
mv "${SCAN_PATH}/.footprint/metadata.tar.gz.tmp" "${SCAN_PATH}/.footprint/metadata.tar.gz"
echo -e "\033[2K\rArchives created"

cd "${CURRENT_DIRECTORY}" || exit 1
echo "${START_TIME}|$(date +%s)|FINISHED|${SCANNED_COUNT}|${PROCESSED_COUNT}|${CHANGED_COUNT}|${CACHED_COUNT}|${TOTAL_COUNT}||" > "${FOLDER_STATUS_FILE}";
echo "Finished"
