#!/bin/bash

for IMAGE in *.img
do
  if [ ! -f ${IMAGE}.xz ]; then
    xz --keep -z -9 -T0 -M 80% ${IMAGE}
  fi
done
