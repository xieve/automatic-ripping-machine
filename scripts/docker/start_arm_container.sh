#!/usr/bin/env bash
modprobe -a sg sr_mod vhba
docker rmi arm
docker build . -t arm
docker run \
    -p "8080:8080" \
    -e ARM_UID="1000" \
    -e ARM_GID="100" \
    -e TZ="Europe/Berlin" \
    -v "$(pwd)/.run:/home/arm" \
    -v "$(pwd)/.run/music:/home/arm/music" \
    -v "$(pwd)/.run/logs:/home/arm/logs" \
    -v "$(pwd)/.run/media:/home/arm/media" \
    -v "$(pwd)/.run/config:/etc/arm/config" \
    --device="/dev/sr0:/dev/sr0:rw" \
    --device="/dev/sg0:/dev/sg0:rw" \
    --privileged \
    --name=arm \
    --rm \
    arm
