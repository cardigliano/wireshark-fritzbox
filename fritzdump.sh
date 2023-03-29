#!/bin/bash

if [  $# -lt 1 ]; then 
  echo "Usage: $0 <IP>"
  exit 1
fi 

WGET=/usr/bin/wget
FRITZ_IP=$1
FRITZ_IFACE="2-1"

function get_session_id() {
    local SID
    CHALLENGE=$($WGET -O - "http://$FRITZ_IP/login_sid.lua" 2>/dev/null \
        | sed 's/.*<Challenge>\(.*\)<\/Challenge>.*/\1/')
    CPSTR="$CHALLENGE-$FRITZ_PWD"
    MD5=$(echo -n $CPSTR | iconv -f ISO8859-1 -t UTF-16LE \
        | md5sum -b | awk '{print substr($0,1,32)}')
    RESPONSE="$CHALLENGE-$MD5"
    SID=$($WGET -O - "http://$FRITZ_IP/login_sid.lua?username=$FRITZ_USER&response=$RESPONSE" 2>/dev/null \
        | sed 's/.*<SID>\(.*\)<\/SID>.*/\1/')

    echo "$SID"
}

echo -n "Enter your router username: "; read FRITZ_USER;
echo -n "Enter your router password: "; read -s FRITZ_PWD;
echo

SID=$(get_session_id)

if [ "$SID" == "0000000000000000" ]; then
  echo "Authentication failure!" 1>&2
  exit 1
fi

echo "Capturing traffic.." 1>&2 

$WGET -qO- http://$FRITZ_IP/cgi-bin/capture_notimeout?ifaceorminor=$FRITZ_IFACE\&snaplen=\&capture=Start\&sid=$SID | tshark -i -
