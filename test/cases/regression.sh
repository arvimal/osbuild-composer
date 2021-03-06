#!/bin/bash
set -xeuo pipefail

# Provision the software under tet.
/usr/libexec/osbuild-composer-test/provision.sh

BLUEPRINT_FILE=/tmp/blueprint.toml
COMPOSE_START=/tmp/compose-start.json
COMPOSE_INFO=/tmp/compose-info.json

# Write a basic blueprint for our image.
tee "$BLUEPRINT_FILE" > /dev/null << EOF
name = "redhat-lsb-core"
description = "A base system with redhat-lsb-core"
version = "0.0.1"

[[packages]]
name = "redhat-lsb-core"

[[packages]]
# The nss package is excluded in the RHEL8.4 image type, but it is required by the
# redhat-lsb-core package. This test verifies it can be added again when explicitly
# mentioned in the blueprint.
name = "nss"
EOF

sudo composer-cli blueprints push "$BLUEPRINT_FILE"
sudo composer-cli blueprints depsolve redhat-lsb-core
sudo composer-cli --json compose start redhat-lsb-core qcow2 | tee "${COMPOSE_START}"
COMPOSE_ID=$(jq -r '.build_id' "$COMPOSE_START")

# Wait for the compose to finish.
echo "⏱ Waiting for compose to finish: ${COMPOSE_ID}"
while true; do
    sudo composer-cli --json compose info "${COMPOSE_ID}" | tee "$COMPOSE_INFO" > /dev/null
    COMPOSE_STATUS=$(jq -r '.queue_status' "$COMPOSE_INFO")

    # Is the compose finished?
    if [[ $COMPOSE_STATUS != RUNNING ]] && [[ $COMPOSE_STATUS != WAITING ]]; then
        break
    fi

    # Wait 30 seconds and try again.
    sleep 30
done

jq . "${COMPOSE_INFO}"

# Did the compose finish with success?
if [[ $COMPOSE_STATUS != FINISHED ]]; then
    echo "Something went wrong with the compose. 😢"
    exit 1
fi
