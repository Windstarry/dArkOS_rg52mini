#!/bin/bash

# Write rootfs to disk
sync
e2fsck -p -f ${FILESYSTEM}
resize2fs -M ${FILESYSTEM}
sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 conv=fsync,notrunc
#sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 seek="237569" conv=fsync,notrunc
