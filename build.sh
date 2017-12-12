#!/usr/bin/env bash

set -e

if [ ! "$1" ]; then
    echo "You must specify the function name as parameter"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "Nu such function."
    exit 1
fi

FUNCTION_NAME=${1%/}
VIRTUAL_ENVIRONMENT=.venv

cd ${FUNCTION_NAME}

# Enable virtual environment
if [ ! -d "$VIRTUAL_ENVIRONMENT" ]
then
    echo "Setting up virtual environment"
    python3 -m venv ${VIRTUAL_ENVIRONMENT}
    source ${VIRTUAL_ENVIRONMENT}/bin/activate
    pip install --upgrade pip
    pip install --upgrade setuptools
    pip install -r requirements.txt
    # The following dependencies are satisfied by AWS already, we keep them here
    # in order to support our development
    pip install boto3
else
    source ${VIRTUAL_ENVIRONMENT}/bin/activate
fi

echo "Installing dependencies..."
# Bring dependencies from requirements.txt
pip install -r requirements.txt -t out/${FUNCTION_NAME} --upgrade > /dev/null 2>&1
# Copy the sources there
cp -R *.py out/${FUNCTION_NAME} > /dev/null 2>&1

echo "Create zip bundle..."
# Pack the bundle
cd out/${FUNCTION_NAME} && zip -r9 ../${FUNCTION_NAME}.zip * > /dev/null 2>&1