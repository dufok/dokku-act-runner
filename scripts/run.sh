#!/usr/bin/env bash

# Get the path to the config.yaml file from environment variable or set to default
CONFIG_FILE_PATH=${CONFIG_FILE_PATH:-"/conf/config.yaml"}

# Check if config.yaml exists and create if not
if [[ ! -f "$CONFIG_FILE_PATH" ]]; then
  echo "config.yaml does not exist at $CONFIG_FILE_PATH, generating..."
  act_runner generate-config > $CONFIG_FILE_PATH
  echo "config.yaml has been created at $CONFIG_FILE_PATH You may want to edit this file before proceeding."
  exit 0
fi

if [[ ! -d /data ]]; then
  mkdir -p /data
fi

cd /data

CONFIG_ARG=""
if [[ ! -z "${CONFIG_FILE}" ]]; then
  CONFIG_ARG="--config ${CONFIG_FILE}"
fi
EXTRA_ARGS=""
if [[ ! -z "${GITEA_RUNNER_LABELS}" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} --labels ${GITEA_RUNNER_LABELS}"
fi

# In case no token is set, it's possible to read the token from a file, i.e. a Docker Secret
if [[ -z "${GITEA_RUNNER_REGISTRATION_TOKEN}" ]] && [[ -f "${GITEA_RUNNER_REGISTRATION_TOKEN_FILE}" ]]; then
  GITEA_RUNNER_REGISTRATION_TOKEN=$(cat "${GITEA_RUNNER_REGISTRATION_TOKEN_FILE}")
fi

# Use the same ENV variable names as https://github.com/vegardit/docker-gitea-act-runner

if [[ ! -s .runner ]]; then
  try=$((try + 1))
  success=0

  # The point of this loop is to make it simple, when running both act_runner and gitea in docker,
  # for the act_runner to wait a moment for gitea to become available before erroring out.  Within
  # the context of a single docker-compose, something similar could be done via healthchecks, but
  # this is more flexible.
  while [[ $success -eq 0 ]] && [[ $try -lt ${GITEA_MAX_REG_ATTEMPTS:-10} ]]; do
    act_runner register \
      --instance "${GITEA_INSTANCE_URL}" \
      --token    "${GITEA_RUNNER_REGISTRATION_TOKEN}" \
      --name     "${GITEA_RUNNER_NAME:-`hostname`}" \
      ${CONFIG_ARG} ${EXTRA_ARGS} --no-interactive 2>&1 | tee /tmp/reg.log

    cat /tmp/reg.log | grep 'Runner registered successfully' > /dev/null
    if [[ $? -eq 0 ]]; then
      echo "SUCCESS"
      success=1
    else
      echo "Waiting to retry ..."
      sleep 5
    fi
  done
fi
# Prevent reading the token from the act_runner process
unset GITEA_RUNNER_REGISTRATION_TOKEN
unset GITEA_RUNNER_REGISTRATION_TOKEN_FILE

act_runner daemon ${CONFIG_ARG}
