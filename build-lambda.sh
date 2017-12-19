#!/usr/bin/env bash

set -e

if [ ! "$1" ]; then
    echo "You must specify the function name as parameter"
    exit 1
fi

FUNCTION_NAME=${1%}
if [ ! -d "/workspace/$1" ]; then
    echo "Nu such function."
    exit 1
fi

VIRTUAL_ENVIRONMENT=/workspace/${FUNCTION_NAME}/.venv
# Enable virtual environment
if [ ! -d "$VIRTUAL_ENVIRONMENT" ]
then
    echo "Setting up virtual environment"
    python3 -m venv ${VIRTUAL_ENVIRONMENT}
    source ${VIRTUAL_ENVIRONMENT}/bin/activate
    # The following dependencies are satisfied by AWS already, we keep them here
    # in order to support our development
    pip install boto3
else
    source ${VIRTUAL_ENVIRONMENT}/bin/activate
fi

echo "Installing dependencies..."
# Bring dependencies from requirements.txt
pip install -r /workspace/${FUNCTION_NAME}/requirements.txt -t /tmp/${FUNCTION_NAME} --upgrade > /dev/null 2>&1

echo "Create zip bundle..."
mkdir -p /workspace/${FUNCTION_NAME}/out && \
    cd /tmp/${FUNCTION_NAME} > /dev/null && \
    zip -r9 /workspace/${FUNCTION_NAME}/out/${FUNCTION_NAME}.zip * > /dev/null 2>&1 && \
    cd /workspace/${FUNCTION_NAME} > /dev/null && \
    zip -9 /workspace/${FUNCTION_NAME}/out/${FUNCTION_NAME}.zip *.py > /dev/null 2>&1 && \
    cd - > /dev/null && rm -R /tmp/${FUNCTION_NAME}
