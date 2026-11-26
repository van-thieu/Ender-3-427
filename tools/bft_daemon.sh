#!/bin/sh
# Persistent BFT firmware uploader for the Creality WiFi box (debug build).
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
DBG=$BFT/debug.log

ORIG=/mnt/creality/prt_com.original
QUIET=/mnt/creality/prt_com.quiet

# The firmware filename is baked into the BFT streams by gen_bft.py.
# It MUST be unique for every flash - the bootloader skips a .bin it has
# already installed. Defaults to FW.BIN for older staged streams.
FWNAME=`cat $BFT/fwname 2>/dev/null`
[ -n "$FWNAME" ] || FWNAME=FW.BIN

note() {
  echo "`date +%H:%M:%S` $*" >> $RESULT
  echo "`date +%H:%M:%S` $*" >> $DBG
}

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
  echo "M28 B1 $FWNAME" > $FIFO
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

# stream_once <sync> [first-line] - one whole packet per write, paced.
# first-line is a 1-based line number in packets_<sync>.txt, used to resume
# after Marlin asks for a resend with rs<N> (packet N == line N+1).
stream_once() {
  s=$1
  START=${2:-1}
  exec 3>/dev/ttyUSB0
  sed -n "${START},\$p" $BFT/packets_$s.txt | while read OFF LEN; do
    dd if=$BFT/stream_$s.bin bs=1 skip=$OFF count=$LEN 2>/dev/null >&3
    awk -f $BFT/delay2.awk < /dev/null
  done
  exec 3>&-
}

# Send every connection-CLOSE variant with pacing. Only the packet whose
# sync matches Marlin's state will be accepted; the rest are ignored.
send_close() {
  local N=0
  note "sending connection-CLOSE sweep (256 variants)"
  exec 3>/dev/ttyUSB0
  while [ $N -lt 256 ]; do
    [ -f $BFT/close_$N.bin ] && cat $BFT/close_$N.bin >&3
    awk -f $BFT/delay2.awk < /dev/null
    N=$((N+1))
  done
  exec 3>&-
  note "close sweep done"
  sleep 3
}

# Check whether Marlin is answering normal G-code again.
ascii_ok() {
  local L=`wc -l < $LOG`
  echo "M115" > $FIFO
  sleep 6
  sed -n "$((L + 1)),\$p" $LOG > $PROBE
  grep -q 'FIRMWARE_NAME' $PROBE
}

log_tail() {
  local N=$1
  note "--- last $N log lines ---"
  tail -n $N $LOG >> $DBG
}

do_upload() {
  echo "=== upload started `date` ===" > $RESULT
  echo "=== debug started `date` ===" > $DBG
  note "target firmware file: $FWNAME"
  if [ ! -c /dev/ttyUSB0 ]; then
    note "ABORT: /dev/ttyUSB0 is not a device (printer USB not connected)"
    return 1
  fi
  use_quiet_daemon || { note "quiet daemon unavailable"; return 1; }
  ATTEMPT=1
  RC=1
  while [ $ATTEMPT -le 3 ]; do
    S=`probe_sync`
    note "attempt $ATTEMPT sync=$S"
    [ -f $BFT/stream_$S.bin ] || { note "no stream for sync $S"; break; }
    MARK=`wc -l < $LOG`
    stream_once $S 1
    sleep 2
    # Marlin may ask for a resend of packet N (rsN). Resume from N+1
    # instead of restarting the whole upload - restarting never works
    # because the printer stays in BFT mode with a stale sync.
    R=0
    while [ $R -lt 5 ]; do
      sed -n "$((MARK + 1)),\$p" $LOG > $RECENT
      RS=`grep -o 'rs[0-9][0-9]*' $RECENT | head -1 | sed 's/rs//'`
      ACK=`grep -o 'ok[0-9][0-9]*' $RECENT | wc -l`
      [ -n "$RS" ] || break
      RESUME=$((RS + 1))
      note "resend rs$RS - resuming from packet $RS (pass $R, ack=$ACK)"
      MARK=`wc -l < $LOG`
      stream_once $S $RESUME
      sleep 2
      R=$((R+1))
    done
    sed -n "$((MARK + 1)),\$p" $LOG > $RECENT
    RS=`grep -o 'rs[0-9][0-9]*' $RECENT | head -1 | sed 's/rs//'`
    ACK=`grep -o 'ok[0-9][0-9]*' $RECENT | wc -l`
    note "final resend=$RS ack=$ACK"
    if [ -n "$RS" ]; then
      note "still resending - exiting BFT mode before retry"
      send_close
      ascii_ok || { stty -F /dev/ttyUSB0 hupcl; restore_daemon; sleep 8; stty -F /dev/ttyUSB0 -hupcl; }
      ATTEMPT=$((ATTEMPT+1))
      continue
    fi
    # The box's log drops many 'okN' lines, so ACK is only a rough sanity
    # check. "No resend requested" is the real sign the stream went through.
    if [ -z "$RS" ] && [ $ACK -gt 1000 ]; then
      note "full transfer acknowledged"
      send_close
      if ascii_ok; then
        note "printer back in ASCII mode"
      else
        note "still binary - forcing DTR reset"
        stty -F /dev/ttyUSB0 hupcl
        restore_daemon
        sleep 8
        stty -F /dev/ttyUSB0 -hupcl
        ascii_ok && note "DTR reset restored ASCII" || note "DTR reset did NOT restore ASCII"
      fi
      # Confirm the .bin landed on the printer's SD, then reboot into the
      # Creality bootloader so it gets installed.
      echo "M21" > $FIFO
      sleep 3
      echo "M20 F" > $FIFO
      sleep 4
      log_tail 120
      echo "M997" > $FIFO
      note "M997 sent (install)"
      sleep 12
      note "post-reboot M115:"
      ascii_ok && note "printer answered M115 after M997" || note "no M115 after M997"
      log_tail 60
      RC=0
      break
    fi
    note "no close confirmation - retrying"
    ATTEMPT=$((ATTEMPT+1))
  done
  [ $RC -eq 0 ] || note "FAILED after 3 attempts"
  restore_daemon
  note "done"
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
