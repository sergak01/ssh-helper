#!/bin/bash

helpFunction() {
  echo "Usage: $0 [serversListFile]"
  echo -e "\t[-m mode] Execution mode. " \
    "\n\t\tmode is one of: " \
    "\n\t\t\"check\" - check access to server" \
    "\n\t\t\"remove\" - remove ssh key from server" \
    "\n\t\t\"add\" - add ssh key to server." \
    "\n\n\t\tDefault: \"check\""
  echo -e "\t[-i] Private key file path to SSH \"-i\" parameter"
  echo -e "\t[-p] Public key file to operation"
  echo -e "\t[-d, --delimiter :] File delimiter (\",\", \":\", etc.). Default: \":\""
  echo -e "\t-h, --help Show help message"
  exit 1 # Exit script after printing help
}

# Init default values
attachmenttype="ASCII"
fileTypeDelimiter=":"
mode="check"

checkLogFile="./check-ssh-access-result.log"
addKeyLogFile="./add-ssh-key-result.log"
removeKeyLogFile="./remove-ssh-key-result.log"

validateFileFunction() {
  fileName=$1

  attachmenttype=$(file $fileName | cut -d\  -f2)

  if [[ $attachmenttype == "ASCII" || $attachmenttype == "CSV" ]]; then
    case $attachmenttype in
    CSV)
      fileTypeDelimiter=","
      ;;
    esac

    return 0
  else
    echo "$attachmenttype"

    return 1
  fi
}

while [[ "$1" != "" ]]; do
  case $1 in
  -m)
    shift
    case $1 in
    check)
      mode="check"
      ;;
    remove)
      mode="remove"
      ;;
    add)
      mode="add"
      ;;
    *)
      echo -e "Error: Unknown mode \"$1\"\n"
      helpFunction
      exit 255
      ;;
    esac
    ;;
  -d | --delimiter)
    shift
    delimiter="$1"
    ;;
  -i)
    shift
    privateKey="$1"
    ;;
  -p)
    shift
    publicKey="$1"
    ;;
  -h | --help)
    helpFunction
    exit
    ;;
  *)
    serversListFile="$1"
    ;;
  esac
  shift
done

while [[ true ]]; do
  if [[ -z "$serversListFile" ]]; then
    echo -n "Type valid path to file with servers list (default: ./servers.list): "
    read serversListFile

    if [[ -z "$serversListFile" ]]; then
      serversListFile="./servers.list"
    fi
  fi

  if [[ -f "$serversListFile" ]]; then
    validateFileFunction "$serversListFile"

    validationResult=$?

    if [[ "$validationResult" == 1 ]]; then
      echo "File type \"$attachmenttype\" is invalid. Please enter path to valid file"

      serversListFile=""
    else
      if [[ -z "$delimiter" ]]; then
        if [[ ! -z "$fileTypeDelimiter" ]]; then
          delimiter="$fileTypeDelimiter"
        else
          delimiter=":"
        fi
      fi

      break
    fi
  else
    echo "File path \"$serversListFile\" is invalid"

    serversListFile=""
  fi
done

while [[ true ]]; do
  if [[ "$mode" == "check" ]]; then
    pubKey=""
    break
  fi

  if [[ -z "$publicKey" ]]; then
    echo -n "Type valid path to publicKey file: "
    read publicKey
  fi

  if [[ -f "$publicKey" ]]; then
    pubKey="$(cat $publicKey | sed -e ':a;N;$!ba;s/\n//g')"

    break
  else
    echo "File path \"$publicKey\" is invalid"

    publicKey=""
  fi
done

log="# Ip address/hostname,Port,Username,Status,Date\n"

# Commands
checkCommand="echo 0"

addCommand="result=\$(grep '$pubKey' ~/.ssh/authorized_keys)
if [[ \$? = 0 ]]; then
  echo 2
else
  echo -e '\n$pubKey\n' >> ~/.ssh/authorized_keys
  echo \$?
fi"

removeCommand="result=\$(grep '$pubKey' ~/.ssh/authorized_keys && sed -i.bak '\#$pubKey#d' ~/.ssh/authorized_keys)
echo \$?"

while IFS=$(echo -e "$delimiter") read -r Host Port Username Status Date || [ -n "$Host" ]; do
  if [[ "${Host:0:1}" == "#" ]]; then
    continue
  fi

  if [[ $Status != "success" && $Status != "not-fount" ]]; then
    if [[ -z $Username ]]; then
      Username="root"
    fi

    if [[ -z $Port ]]; then
      Port=22
    fi

    case $mode in
    check)
      logFile="$checkLogFile"
      command="$checkCommand"
      ;;
    add)
      logFile="$addKeyLogFile"
      command="$addCommand"
      ;;
    remove)
      logFile="$removeKeyLogFile"
      command="$removeCommand"
      ;;
    esac

    if [[ ! -z $privateKey ]]; then
      sshResult=$(ssh -o ConnectTimeout=5 -n -i "$privateKey" "$Username@$Host" -p "$Port" "$command" 2>&1)
    else
      sshResult=$(ssh -o ConnectTimeout=5 -n "$Username@$Host" -p "$Port" "$command" 2>&1)
    fi

    statusCode=$?

    if [[ $statusCode == 255 ]]; then
      if [[ $sshResult == *"Permission denied"* ]]; then
        Status="access-denied"
      elif [[ $sshResult == *"Connection refused"* ]]; then
        Status="no-connect"
      elif [[ $sshResult == *"Connection timed out"* ]]; then
        Status="timeout"
      else
        Status="unknown"
      fi
    else
      if [[ $sshResult == 0 ]]; then
        Status="success"
      elif [[ $sshResult == 1 ]]; then
        Status="not-found"
      elif [[ $sshResult == 2 ]]; then
        Status="exists"
      else
        echo "$sshResult"
      fi
    fi

    Date=$(date '+%Y-%m-%d %H:%M:%S %z' -u)
  fi

  log="${log}${Host},${Port},${Username},${Status},${Date}\n"

  printf 'IP/Hostname: %30s\tPort: %5d\tUsername: %15s\tStatus: %13s\tDate: %15s\n' "$Host" "$Port" "$Username" "$Status" "$Date"
done <"$serversListFile"

echo -e "$log" >>"$logFile"
