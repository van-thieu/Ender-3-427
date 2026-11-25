#!/bin/sh
# Persistent BFT firmware uploader for the Creality WiFi box.
# Ignore hangup so the daemon survives the telnet session that started it.
trap '' HUP
# Trigger: create /media/mmcblk0p1/creality/bft/trigger
# Result:  /media/mmcblk0p1/creality/bft/result.txt
SD=/media/mmcblk0p1/creality
BFT=$SD/bft
LOG=$SD/log/prt_com.log
FIFO=/tmp/serailupfifo
RESULT=$BFT/result.txt
RECENT=$BFT/recent.log
PROBE=$BFT/probe.log

ORIG=/mnt/creality/prt_com.original
QUIET=/mnt/creality/prt_com.quiet

use_quiet_daemon() {
  [ -f $QUIET ] || return 1
  killall crond
  killall -9 prt_com
  cp -f /home/prt_com $ORIG
  cp -f $QUIET /home/prt_com
  chmod 777 /home/prt_com
  /home/prt_com &
  sleep 3
}

restore_daemon() {
  [ -f $ORIG ] || return 1
  killall -9 prt_com
  cp -f $ORIG /home/prt_com
  chmod 777 /home/prt_com
  /home/prt_com &
  crond
  sleep 2
}

probe_sync() {
  echo "M28 B1 FW.BIN" > $FIFO
  sleep 2
  local L=`wc -l < $LOG`
  cat $BFT/sync.bin > /dev/ttyUSB0
  sleep 6
  sed -n "$((L + 1)),\$p" $LOG > $PROBE
  grep -o 'ss[0-9]*,96,0\.1\.0' $PROBE | tail -1 | sed 's/ss\([0-9]*\).*/\1/'
}

current_sync() {
  local L=`wc -l < $LOG`
  cat $BFT/sync.bin > /dev/ttyUSB0
  sleep 5
  sed -n "$((L + 1)),\$p" $LOG > $PROBE
  grep -o 'ss[0-9]*,96,0\.1\.0' $PROBE | tail -1 | sed 's/ss\([0-9]*\).*/\1/'
}

stream_once() {
  s=$1
  stty -F /dev/ttyUSB0 -hupcl 115200
  # CRITICAL: never split a BFT packet across writes. Marlin times out
  # waiting for the rest of a partial packet. chunks_<sync>.txt holds
  # byte ranges that each contain a whole number of packets.
  # Do NOT run stty here - opening/closing the port toggles DTR and RESETS
  # the Creality board mid-transfer.
  exec 3>/dev/ttyUSB0
  while read OFF LEN; do
    dd if=$BFT/stream_$s.bin bs=1 skip=$OFF count=$LEN 2>/dev/null >&3
    # ~95ms sub-second gap (BusyBox sleep cannot do fractions). Must stay
    # below Marlin's PACKET_MAX_WAIT (500ms) between packets.
    awk -f $BFT/delay2.awk < /dev/null
  done < $BFT/packets_$s.txt
  exec 3>&-
}

do_upload() {
  echo "=== upload started `date` ===" > $RESULT
  use_quiet_daemon || { echo "quiet daemon unavailable" >> $RESULT; return 1; }
  ATTEMPT=1
  RC=1
  while [ $ATTEMPT -le 3 ]; do
    S=`probe_sync`
    echo "attempt $ATTEMPT sync=$S" >> $RESULT
    [ -f $BFT/stream_$S.bin ] || { echo "no stream for sync $S" >> $RESULT; break; }
    MARK=`wc -l < $LOG`
    stream_once $S
    sleep 2
    sed -n "$((MARK + 1)),\$p" $LOG > $RECENT
    RS=`grep -o 'rs[0-9][0-9]*' $RECENT | tail -1`
    ACK=`grep -o 'ok[0-9][0-9]*' $RECENT | wc -l`
    if [ -n "$RS" ]; then
      echo "  resend requested: $RS - retrying" >> $RESULT
      ATTEMPT=$((ATTEMPT+1))
      continue
    fi
    echo "  acknowledged packets: $ACK" >> $RESULT
    if [ $ACK -gt 1700 ]; then
      # Full transfer acknowledged. Send connection CLOSE so Marlin
      # switches back to ASCII mode (its own close packet is unreliable).
      J=0
      while [ $J -lt 4 ]; do
        CS=`current_sync`
        [ -f $BFT/close_$CS.bin ] && cat $BFT/close_$CS.bin > /dev/ttyUSB0
        sleep 1
        J=$((J+1))
      done
      echo "SUCCESS - triggering M21 + M997" >> $RESULT
      echo "M21" > $FIFO
      sleep 1
      echo "M997" > $FIFO
      RC=0
      break
    fi
    echo "  no close confirmation - retrying" >> $RESULT
    ATTEMPT=$((ATTEMPT+1))
  done
  [ $RC -eq 0 ] || echo "FAILED after 3 attempts" >> $RESULT
  restore_daemon
  return $RC
}

echo "daemon started `date`" > $BFT/daemon.log
while true; do
  if [ -f $BFT/trigger ]; then
    rm -f $BFT/trigger
    do_upload
    echo "done `date`" >> $BFT/daemon.log
  fi
  sleep 5
done
