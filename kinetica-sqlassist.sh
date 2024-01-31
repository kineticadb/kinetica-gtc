#! /usr/bin/env bash

# Run script to start the Kinetica's SqlAssist Docker container and a local
# Kinetica DB docker container using the local GPUs.
#
# Copyright (c) 2023, Chad Juliano, John Labenski, Kinetica DB Inc.
##

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$( cd "$( dirname "$( readlink -m "${BASH_SOURCE[0]}")")" && pwd )"
pushd "$SCRIPT_DIR" > /dev/null

# ---------------------------------------------------------------------------

SQLASSIST_PORT="${SQLASSIST_PORT:-8050}"
SQLASSIST_DOCKER_NAME="kinetica-sqlassist"

JUPYTER_PORT="${JUPYTER_PORT:-10000}"
JUPYTER_DOCKER_NAME="kinetica-jupyter"

# ---------------------------------------------------------------------------
# Get and start the sqlassist docker container.

if ! docker ps --format '{{.Names}}' | grep -q "^$SQLASSIST_DOCKER_NAME\$"; then
    #docker pull kinetica/sqlassist
    if docker ps -a --format '{{.Names}}' | grep -q "^$SQLASSIST_DOCKER_NAME\$"; then
        docker rm "$SQLASSIST_DOCKER_NAME" # remove if stopped
    fi

    SQLASSIST_CMD=( docker run --rm --detach --name "$SQLASSIST_DOCKER_NAME" \
                    --gpus 'device=0' --publish "$SQLASSIST_PORT:8050" \
                    kinetica/sqlassist )
    echo "> ${SQLASSIST_CMD[*]}"
    "${SQLASSIST_CMD[@]}"
fi

if ! SQLASSIST_IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}},{{end}}' "$SQLASSIST_DOCKER_NAME" | cut -d, -f1); then
    echo "error: Unable to determine the IP address of the '$SQLASSIST_DOCKER_NAME' docker container."
    exit 1
fi

echo "Found $SQLASSIST_DOCKER_NAME docker container has IP=$SQLASSIST_IP"
echo

# ---------------------------------------------------------------------------
# Get jupyterlab docker image and mount the workbook directory.

JUPYTER_TOKEN_FILE="/home/jovyan/.local/share/jupyter/runtime/jpserver-7.json"
if ! docker ps --format '{{.Names}}' | grep -q "^$JUPYTER_DOCKER_NAME\$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^$JUPYTER_DOCKER_NAME\$"; then
        docker rm "$JUPYTER_DOCKER_NAME" # remove if stopped
    fi

    JUPYTER_CMD=( docker run --rm --detach --name "$JUPYTER_DOCKER_NAME" \
                  --publish "$JUPYTER_PORT:8888" \
                  -v "$PWD/jupyter:/home/jovyan/work" \
                  quay.io/jupyter/scipy-notebook )
    echo "> ${JUPYTER_CMD[*]}"
    "${JUPYTER_CMD[@]}"
    sleep 4

    while ! docker exec ls -al "$JUPYTER_TOKEN_FILE" &> /dev/null; do
        echo "Waiting for Jupyterlab to start... $SECONDS"
        sleep 4
    done
fi

if ! JUPYTER_IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}},{{end}}' "$JUPYTER_DOCKER_NAME" | cut -d, -f1); then
    echo "error: Unable to determine the IP address of the '$JUPYTER_DOCKER_NAME' docker container."
    exit 1
fi

if ! JUPYTER_TOKEN=$(docker exec "$JUPYTER_DOCKER_NAME" grep '"token"' "$JUPYTER_TOKEN_FILE" | cut -d: -f2 | sed 's/^[ "]*//g; s/[ ",]*$//g'); then
    echo "error: Unable to determine the Jupyter token in the '$JUPYTER_DOCKER_NAME' docker container."
    exit 1
fi

echo "Found $JUPYTER_DOCKER_NAME docker container has IP=$JUPYTER_IP Token=$JUPYTER_TOKEN"
echo

# ---------------------------------------------------------------------------
# Get the developer script, configure to use llm, and start the Kinetica DB.

if ! [ -f ./kinetica ]; then
    curl https://files.kinetica.com/install/kinetica.sh -o kinetica && chmod u+x kinetica
fi

CMD=(./kinetica --docker-run-args --runtime=nvidia
     --conf "ai.api.provider=kineticallm" \
     --conf "ai.api.url=http://$SQLASSIST_IP:8050/sql/suggest" \
     rm start)
echo "> DOCKER_IMAGE_REPO=kineticadevcloud/kinetica-gpu DOCKER_IMAGE_TAG=7.2.0 ${CMD[*]}"

DOCKER_IMAGE_REPO=kineticadevcloud/kinetica-gpu DOCKER_IMAGE_TAG=7.2.0 "${CMD[@]}"

echo
echo "Access Jupyterlab at http://127.0.0.1:$JUPYTER_PORT/lab?token=$JUPYTER_TOKEN"
echo "                  or http://$JUPYTER_IP:8888/lab?token=$JUPYTER_TOKEN"
