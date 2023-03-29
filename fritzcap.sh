#!/bin/bash

EXTCAP_VERSION="0.0.2"
WGET=/usr/bin/wget
DEFAULT_FRITZ_IFACE="2-1"

while [ "$1" != "" ]; do
    case $1 in
        --extcap-interfaces)
			echo "extcap {version=$EXTCAP_VERSION}"
			echo "interface {value=fritzcap}{display=FRITZ!Box remote capture}"
            shift
            ;;
        --extcap-config)
			echo "arg {number=0}{call=--ifname}{display=Interface Name}{type=selector}{tooltip=FRITZ!Box capture interface }"
			echo "value {arg=0}{value=2-1}{display=Internet}{default=true}"
			echo "value {arg=0}{value=3-}{display=Routing Interface}{default=false}"
			echo "value {arg=0}{value=1-lan}{display=LAN}{default=false}"
			echo "arg {number=1}{call=--host}{display=FRITZ!Box IP address}{type=string}{tooltip=The FRITZ!Box IP address or hostname}{required=true}"
			echo "arg {number=2}{call=--username}{display=FRITZ!Box user}{type=string}{tooltip=The FRITZ!Box username (usually not required)}"
			echo "arg {number=3}{call=--password}{display=FRITZ!Box password}{type=password}{tooltip=The FRITZ!Box password}{required=true}"
            ;;
        --extcap-interface)
			# Nothing to do as we support only 1 interface
            shift
            ;;
        --capture)
			CAPTURE=1
            ;;
        --fifo)
			FIFO=$2
            shift
            ;;
        --ifname)
			FRITZ_IFACE=$2
            shift
            ;;
        --host)
			FRITZ_IP=$2
            shift
            ;;
        --username)
			FRITZ_USER=$2
            shift
            ;;
        --password)
			FRITZ_PWD=$2
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option $1" 1>&2
            ;;
    esac
	shift
done

if [ -z "$CAPTURE" ]; then
	exit
fi
	
if [ -z "$FRITZ_IFACE" ]; then
	FRITZ_IFACE="$DEFAULT_FRITZ_IFACE"
fi

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

SID=$(get_session_id)

if [ "$SID" == "0000000000000000" ]; then
  echo "Authentication failure!" 1>&2
  exit 1
fi

$WGET -qO- "http://$FRITZ_IP/cgi-bin/capture_notimeout?ifaceorminor=$FRITZ_IFACE&snaplen=1600&capture=Start&sid=$SID" > $FIFO
