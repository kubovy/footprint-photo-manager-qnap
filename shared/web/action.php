<?php
/******************************************************************************
 * Copyright (C) 2020 Jan Kubovy (jan@kubovy.eu)                              *
 *                                                                            *
 * This program is free software: you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by       *
 * the Free Software Foundation, either version 3 of the License, or          *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License          *
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.      *
 ******************************************************************************/
error_reporting(E_ALL);
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
$listFile = "/etc/config/footprint.list";
$sharePrefix = "/share";
$folderDirectory = ".footprint";
$statusFile = "${folderDirectory}/status";
$scanNowFile = "${folderDirectory}/scannow";
$stopFile = "${folderDirectory}/stop";

function readFolderList() {
    global $listFile;
    $folders = array();
    if (file_exists($listFile)) {
        $handle = fopen($listFile, "r");
        if ($handle) {
            while (($line = fgets($handle)) !== false) {
                //echo "${line}";
                $line = preg_replace("/\n/", "", $line);
                $folders[] = $line;
                //array_push($folders, $line);
            }
            fclose($handle);
        } else {
            http_response_code(500);
            echo "\"Could not access list\"";
            exit(0);
        }
    }
    return $folders;
}

function writeFolderList($folders) {
    global $listFile;
    $handle = fopen($listFile, "w");
    if ($handle) {
        foreach ($folders as $folder) {
            fwrite($handle, "${folder}\n");
        }
        fclose($handle);
        echo "\"OK\"";
    } else {
        http_response_code(500);
        echo "\"Could not change list\"";
        exit(0);
    }
}

function getStatus($folder) {
    global $sharePrefix;
    global $statusFile;
    global $stopFile;
    global $scanNowFile;
    $starting = file_exists("${sharePrefix}${folder}/${scanNowFile}");
    $stopping = file_exists("${sharePrefix}${folder}/${stopFile}");
    $shareFolder = "${sharePrefix}${folder}";
    $file = "${shareFolder}/${statusFile}";
    if (file_exists($file)) {
        $content = file_get_contents($file);
        $part = preg_split("/\|/", $content);
        // Script    : PREPARING, SCANNING, ARCHIVING, FINISHED, STOPPED
        // Additional: QUEUED, STOPPING, NOP
        $action = $part[2];
        if (($action == "FINISHED" || $action == "STOPPED") && $starting) {
            $action = "QUEUED";
        } else if ($action != "FINISHED" && $action != "STOPPED" && $stopping) {
            $action = "STOPPING";
        }
        return array(
            "startTime" => intval($part[0]),
            "processTime" => intval($part[1]),
            "action" => $action,
            "scannedCount" => intval($part[3]),
            "processedCount" => intval($part[4]),
            "changedCount" => intval($part[5]),
            "cachedCount" => intval($part[6]),
            "totalCount" => intval($part[7]),
            "path" => $part[8],
            "mode" => $part[9]);
    } else {
        return array(
            "startTime" => 0,
            "processTime" => 0,
            "action" => $starting ? "QUEUED" : "NOP",
            "scannedCount" => 0,
            "processedCount" => 0,
            "changedCount" => 0,
            "cachedCount" => 0,
            "totalCount" => 0,
            "path" => "",
            "mode" => "");
    }
}

function removePathPrefix($input) {
    global $sharePrefix;
    if (substr($input, 0, strlen($sharePrefix)) == $sharePrefix) {
        return substr($input, strlen($sharePrefix));
    }
    return $input;
}

function getSubDirectories($path) {
    global $sharePrefix;
    $directories = array();
    if (strlen($path) > 0 && substr($path, 0, 1) == "/") {
        $path = substr($path, 1);
        if ($path != "") {
            $parts = preg_split("/\//", $path);
            array_pop($parts);
            $path = implode("/", $parts);
            if ($path != "") {
                $directories = glob("${sharePrefix}/${path}/*", GLOB_ONLYDIR);
                $directories = array_map("removePathPrefix", $directories);
            }
        }
    }
    return $directories;
}

$queryParts = preg_split("/&/", $_SERVER['QUERY_STRING']);
$query = array("nop" => "");
for ($i = 0; $i < count($queryParts); ++$i) {
    $part = preg_split("/=/", $queryParts[$i]);
    $query[$part[0]] = urldecode($part[1]);
}
if (!in_array("action", array_keys($query))) {
    http_response_code(400);
    echo "\"No action specified\"";
    exit(0);
}

switch ($query["action"]) {
    case "folders-status":
        $status = array();
        foreach (readFolderList() as $folder) {
            $status[] = array(
                "folder" => $folder,
                "status" => getStatus($folder));
        }
        echo json_encode($status);
        exit(0);
        break;
    case "folder-add":
        foreach ($_POST as $key => $value) {
            if ($key == "folder") {
                $value = urldecode($value);
                $folders = readFolderList();
                if (!in_array($value, $folders)) array_push($folders, $value);
                writeFolderList($folders);
            }
        }
        exit(0);
        break;
    case "folder-delete":
        foreach ($_POST as $key => $value) {
            if ($key == "folder") {
                $value = urldecode($value);
                $folders = readFolderList();
                $index = array_search($value, $folders);
                if ($index !== false) unset($folders[$index]);
                writeFolderList($folders);
            }
        }
        exit(0);
        break;
    case "folder-list":
        $folders = readFolderList();
        echo json_encode($folders);
        exit(0);
        break;
    case "folder-scan":
        if (array_key_exists('folder', $_POST)) {
            $folder = urldecode($_POST['folder']);
            if (file_exists("${sharePrefix}${folder}/${stopFile}")) {
                unlink("${sharePrefix}${folder}/${stopFile}");
            }
            if (!file_exists("${sharePrefix}${folder}/${$folderDirectory}")) {
                mkdir("${sharePrefix}${folder}/${$folderDirectory}");
            }
            touch("${sharePrefix}${folder}/${scanNowFile}");
        }
        exit(0);
        break;
    case "folder-stop":
        if (array_key_exists('folder', $_POST)) {
            $folder = urldecode($_POST['folder']);
            if (file_exists("${sharePrefix}${folder}/${scanNowFile}")) {
                unlink("${sharePrefix}${folder}/${scanNowFile}");
            }
            if (!file_exists("${sharePrefix}${folder}/${$folderDirectory}")) {
                mkdir("${sharePrefix}${folder}/${$folderDirectory}");
            }
            touch("${sharePrefix}${folder}/${stopFile}");
        }
        exit(0);
        break;
    case "autocomplete":
        if (in_array("term", array_keys($query))) {
            echo json_encode(getSubDirectories($query["term"]), JSON_UNESCAPED_SLASHES);
        } else {
            http_response_code(400);
            echo "\"No query specified\"";
        }
        exit(0);
        break;
    default:
        http_response_code(400);
        echo "\"Unknown action\"";
        exit(0);
        break;
}
?>