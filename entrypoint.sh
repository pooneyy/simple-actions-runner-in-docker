#!/bin/bash

SCRIPT_NAME=$(basename "$0")-$(date +"%Y%m%d-%H%M%S")
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
LOG_FILE="./.runner_logs/${SCRIPT_NAME}.log"
RUNNER_PID=""
CONFIG_DIR="./.runner_config"
ERROR_MSG="A runner with the name [$RUNNER_NAME] already exists in the repository (enterprise or organization). Automatic remove failed, and you need to manually remove it at github.com to be able to recreate a runner named $RUNNER_NAME."
if [ -z "${ROLE}" ] || [ -z "${REPO}" ] || [ -z "${RUNNER_GITHUB_TOKEN}" ]; then
  echo "Error: Missing required environment variables ROLE, REPO, GITHUB_TOKEN" >&2
  exit 1
fi
if [ -z "${RUNNER_NAME}" ]; then
    RUNNER_NAME=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 12 | head -n 1)
    export RUNNER_NAME
fi
if [ -z "${RUNNER_LABELS}" ]; then
    RUNNER_LABELS="self-hosted-runner"
    export RUNNER_LABELS
fi
if [ -z "${WORK_FOLDER}" ]; then
    WORK_FOLDER=""
    export WORK_FOLDER
fi
if [ -z "${RUNNER_GROUP}" ]; then
    RUNNER_GROUP="Default"
    export RUNNER_GROUP
fi
if [ -z "${AUTO_UNREGISTER}" ]; then
    AUTO_UNREGISTER=false
    export AUTO_UNREGISTER
fi
export FORCE_UNREGISTER=false

log() {
  local level="$1"
  shift
  local log_prefixes="[ENTRYPOINT $(date --rfc-3339=seconds) $level]"
  local message="$@"
  local log_content="$log_prefixes $message"
  echo "$log_content" >&2
  echo "$log_content" >> "$LOG_FILE"
}

init() {
  log "INFO" "init..."
  touch "$LOG_FILE" 2>/dev/null || {
    echo "Error: Unable to create log file $LOG_FILE" >&2
    exit 1
  }
}

cleanup() {
  local signal=${1:-"normal exit"}
  log "INFO" "capture signal: $signal"
  log "INFO" "Clean Lock File..."
  
  if [ ! -z "$RUNNER_PID" ] && kill -0 $RUNNER_PID 2>/dev/null; then
    log "INFO" "Killing Runner.Listener process (PID: $RUNNER_PID)"
    kill -TERM $RUNNER_PID 2>/dev/null
    wait $RUNNER_PID 2>/dev/null
  fi
  
  rm -f "$LOCK_FILE"
  
  if [ "$AUTO_UNREGISTER" = true ] || [ "$FORCE_UNREGISTER" = true ]; then
    ./bin/Runner.Listener remove --token $(get_registration_token) > /dev/null 2>&1
    rm -f $CONFIG_DIR/.[^.]*
    log "INFO" "Self-host Runner Unregistered"
  fi
  exit 0
}

set_traps() {
  trap 'cleanup SIGTERM' TERM
  trap 'cleanup SIGINT' INT
  trap 'cleanup SIGQUIT' QUIT
  trap 'cleanup EXIT' EXIT
}

get_registration_token() {
  response=$(curl -sL -w "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $RUNNER_GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/$ROLE/$REPO/actions/runners/registration-token)
  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    status_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | sed '$d')
    if [ "$status_code" = "201" ]; then
      echo  "$response_body" | jq -r '.token'
    else
      log "DEBUG" "$response_body"
      exit 1
    fi
  else
    log "ERROR" "curl failed with exit code $exit_code in function get_registration_token"
    exit 1
  fi
}

get_runner_id() {
  log "DEBUG" "Try to get Runner ID..."
  id=$(curl -sL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $RUNNER_GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/$ROLE/$REPO/actions/runners?name=$RUNNER_NAME \
      | jq -r '.runners[0].id // empty')
  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    if [ -n "$id" ]; then
      log "DEBUG" "Runner ID: $id"
      runner_info=$(curl -sL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $RUNNER_GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/$ROLE/$REPO/actions/runners/$id)
      log "DEBUG" "Runner Info: $runner_info"
      name=$(echo $runner_info | jq -r '.name')
      busy=$(echo $runner_info | jq -r '.busy')
      if [ "$name" = "$RUNNER_NAME" ] && [ "$busy" = false ]; then
        echo "$id"
      else
        echo "0" # it means the runner must be manually unregistered
      fi
    else
      echo "-1" # it means runner not found
    fi
  else
    log "ERROR" "curl failed with exit code $exit_code in function get_runner_id"
    exit 1
  fi
}

try_delete_runner() {
  log "DEBUG" "Try to delete the same name runner if it exists and not busies..."
  runner_id=$(get_runner_id)
  if [ "$runner_id" != "0" ] && [ "$runner_id" != "-1" ]; then
    response=$(curl -sL -w "%{http_code}" \
      -X DELETE \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $RUNNER_GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/$ROLE/$REPO/actions/runners/$runner_id)
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
      status_code=$(echo "$response" | tail -n 1)
      response_body=$(echo "$response" | sed '$d')
      if [ "$status_code" = "204" ]; then
          echo true
      else
          log "DEBUG" "$response_body"
          echo false
      fi
    else
      log "ERROR" "curl failed with exit code $exit_code in function try_delete_runner"
      echo false
    fi
  elif [ "$runner_id" = "-1" ]; then
    log "INFO" "Can not find the runner with the name [$RUNNER_NAME] in the repository (enterprise or organization)."
    echo true
  elif [ "$runner_id" = "0" ]; then
    # it means the runner must be manually unregistered
    echo false
  fi
}

main() {
  init
  set_traps
  log "INFO" "PID: $$"
  echo $$ > "$LOCK_FILE" 2>/dev/null || {
    log "WARNING" "Warning: Unable to create lock file $LOCK_FILE"
  }
  runner_id=$(get_runner_id)
  if [ "$runner_id" != "0" ] && [ "$runner_id" != "-1" ]; then
    if [ -n "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
        cp $CONFIG_DIR/.[^.]* ./
    fi
  elif [ "$runner_id" = "-1" ] || [ "$runner_id" = "0" ]; then
    rm -f $CONFIG_DIR/.[^.]*
    if [ "$runner_id" = "0" ]; then
      log $ERROR_MSG
      exit 1
    fi
  fi
  if ./bin/Runner.Listener > /dev/null 2>&1; then
      log "INFO" "Self-host Runner Registered"
  else
      log "INFO" "Self-host Runner Not Registered"
      rm -f .credentials .credentials_rsaparams .runner
      result=$(try_delete_runner)
      log "DEBUG" "Try Delete Runner Result: [$result]"
      if [ "$result" = true ]; then
        if ./bin/Runner.Listener configure --unattended \
              --url https://github.com/$REPO \
              --token $(get_registration_token) \
              --name $RUNNER_NAME \
              --labels $RUNNER_LABELS \
              --work $WORK_FOLDER \
              --runnergroup $RUNNER_GROUP > /dev/null 2>&1; then
          log "INFO" "Self-host Runner Registered"
          cp -f .credentials .credentials_rsaparams .runner $CONFIG_DIR/
        else
          log "ERROR" "Self-host Runner Registration Failed"
          exit 1
        fi
      else
        log $ERROR_MSG
        exit 1
      fi
  fi
  updateFile="update.finished"
  while :; do
    ./bin/Runner.Listener run &
    RUNNER_PID=$!
    log "INFO" "Runner.Listener started with PID: $RUNNER_PID"
    
    wait $RUNNER_PID
    RUNNER_EXIT_CODE=$?
    case $RUNNER_EXIT_CODE in
      0)
        log "INFO" "Runner listener exit with 0 return code, stop the service, no retry needed."
        break
        ;;
      1)
        log "ERROR" "Runner listener exit with terminated error, stop the service, no retry needed."
        touch force.do.not.start
        export FORCE_UNREGISTER=true
        break
        ;;
      2)
        log "INFO" "Runner listener exit with retryable error, re-launch runner in 5 seconds."
        ./safe_sleep.sh 5
        ;;
      3|4)
        log "INFO" "Runner listener exit because of updating, re-launch runner after successful update"
        for i in {0..600}; do
          if [ -f "$updateFile" ]; then
            log "INFO" "Update finished successfully."
            break
          fi
          ./safe_sleep.sh 1
        done
        if [ ! -f "$updateFile" ]; then
          log "INFO" "Runner Listener update timeout"
          break
        else
          rm -f "$updateFile"
        fi
        ;;
      5)
        log "ERROR" "Runner listener exit with Session Conflict error, stop the service, no retry needed."
        break
        ;;
      *)
        log "ERROR" "Exiting with unknown error code: ${RUNNER_EXIT_CODE}"
        break
    esac
  done
  log "INFO" "Runner.Listener process (PID: $RUNNER_PID) exited with code: $RUNNER_EXIT_CODE"
}
if [ ! -f "force.do.not.start" ]; then
  main "$@"
else
  log "WARNING" "Find the "Force Do Not Start" flag file, if you want to start the Runner, please recreate the container"
fi
