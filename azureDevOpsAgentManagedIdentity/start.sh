#!/bin/bash
set -e

if [ -z "$AZP_URL" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

if [ -z "$AZP_TOKEN_FILE" ]; then
  # Check if MANAGED_IDENTITY_OBJECT_ID is present
  if [ -n "$MANAGED_IDENTITY_OBJECT_ID" ]; then
    response=$(curl -s "$IDENTITY_ENDPOINT?api-version=2019-08-01&resource=499b84ac-1321-427f-aa17-267ca6975798&object_id=$MANAGED_IDENTITY_OBJECT_ID" -H X-IDENTITY-HEADER:$IDENTITY_HEADER)
    AZP_TOKEN=$(echo "$response" | jq -r '.access_token')

    if [ -z "$AZP_TOKEN" ]; then
      echo 1>&2 "error: failed to retrieve token using MANAGED_IDENTITY_OBJECT_ID"
      exit 1
    fi
  elif [ -z "$AZP_TOKEN" ]; then
    # Fall back to the AZP_TOKEN variable if APPLICATION_ID is not set
    echo 1>&2 "error: missing AZP_TOKEN environment variable"
    exit 1
  fi

  AZP_TOKEN_FILE=/azp/.token
  echo -n $AZP_TOKEN > "$AZP_TOKEN_FILE"
fi

unset AZP_TOKEN

if [ -n "$AZP_WORK" ]; then
  mkdir -p "$AZP_WORK"
fi

export AGENT_ALLOW_RUNASROOT="1"

cleanup() {
  if [ -n "$AZP_PLACEHOLDER" ]; then
    echo 'Running in placeholder mode, skipping cleanup'
    return
  fi
  if [ -e config.sh ]; then
    print_header "Cleanup. Removing Azure Pipelines agent..."

    if [ -n "$MANAGED_IDENTITY_OBJECT_ID" ]; then
      response=$(curl -s "$IDENTITY_ENDPOINT?api-version=2019-08-01&resource=499b84ac-1321-427f-aa17-267ca6975798&object_id=$MANAGED_IDENTITY_OBJECT_ID" -H X-IDENTITY-HEADER:$IDENTITY_HEADER)
      AZP_TOKEN=$(echo "$response" | jq -r '.access_token')

      if [ -z "$AZP_TOKEN" ]; then
      echo 1>&2 "error: failed to retrieve token using MANAGED_IDENTITY_OBJECT_ID"
      exit 1
      fi

      AZP_TOKEN_FILE=/azp/.token
      echo -n $AZP_TOKEN > "$AZP_TOKEN_FILE"
    fi

    # If the agent has some running jobs, the configuration removal process will fail.
    # So, give it some time to finish the job.
    while true; do
      ./config.sh remove --unattended --auth PAT --token $(cat "$AZP_TOKEN_FILE") && break

      echo "Retrying in 30 seconds..."
      sleep 30
    done
  fi
}

print_header() {
  lightcyan='\033[1;36m'
  nocolor='\033[0m'
  echo -e "${lightcyan}$1${nocolor}"
}

# Let the agent ignore the token env variables
export VSO_AGENT_IGNORE=AZP_TOKEN,AZP_TOKEN_FILE

source ./env.sh

print_header "1. Configuring Azure Pipelines agent..."

./config.sh --unattended \
  --agent "${AZP_AGENT_NAME:-$(hostname)}" \
  --url "$AZP_URL" \
  --auth PAT \
  --token $(cat "$AZP_TOKEN_FILE") \
  --pool "${AZP_POOL:-Default}" \
  --work "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula & wait $!

print_header "2. Running Azure Pipelines agent..."

trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# To be aware of TERM and INT signals call run.sh
# Running it with the --once flag at the end will shut down the agent after the build is executed
./run.sh "$@"
