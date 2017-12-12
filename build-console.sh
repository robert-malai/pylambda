#!/usr/bin/env bash
if [[ "$(docker images -q build-console:latest 2> /dev/null)" == "" ]]; then
    echo "Building console image. Please wait..."
    docker build -t build-console . &> /dev/null
fi
docker run -it --rm \
    --name build-console \
    --hostname build-console \
    --volume ~/.aws:/root/.aws:ro \
    --volume `pwd`:/workspace \
    build-console /bin/bash