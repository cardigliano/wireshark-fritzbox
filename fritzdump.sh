#!/bin/bash

if [  $# -lt 1 ]; then 
  echo "Usage: $0 <IP>"
  exit 1
fi 

WGET=/usr/local/bin/wget
FRITZ_IP=$1
FRITZ_USER=""
FRITZ_IFACE="1-lan"

SIDFILE="/tmp/fritz.sid"

if [ ! -f $SIDFILE ]; then
  touch $SIDFILE
fi

SID=$(cat $SIDFILE)

NOTCONNECTED=$(curl -s "http://$FRITZ_IP/login_sid.lua?sid=$SID" | grep -c "0000000000000000")
if [ $NOTCONNECTED -gt 0 ]; then

  read -s -p "Enter Router Password: " FRITZ_PWD
  echo ""

  CHALLENGE=$(curl -s http://$FRITZ_IP/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
  HASH=$(perl -MPOSIX -e '
    use Digest::MD5 "md5_hex";
    my $ch_pw = "$ARGV[0]-$ARGV[1]";
    $ch_pw =~ s/(.)/$1 . chr(0)/eg; 
    my $md5 = lc(md5_hex($ch_pw)); 
    print $md5;
  ' -- "$CHALLENGE" "$FRITZ_PWD")
  curl -s "http://$FRITZ_IP/login_sid.lua" -d "response=$CHALLENGE-$HASH" -d 'username='${FRITZ_USER} | grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2 > $SIDFILE
fi

SID=$(cat $SIDFILE)

if [ "$SID" == "0000000000000000" ]; then
  echo "Authentication error" 1>&2
  exit 1
fi

echo "Capturing traffic.." 1>&2 

$WGET -qO- http://$FRITZ_IP/cgi-bin/capture_notimeout?ifaceorminor=$FRITZ_IFACE\&snaplen=\&capture=Start\&sid=$SID | tshark -i -
