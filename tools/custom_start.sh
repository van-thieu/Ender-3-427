#!/bin/sh
# Boot hook installed through /mnt/creality (see cmp_ver.sh).
trap '' HUP
# Start the persistent BFT uploader in the background.
if [ -f /mnt/creality/bft_daemon.sh ]; then
  /mnt/creality/bft_daemon.sh >/dev/null 2>&1 &
fi
