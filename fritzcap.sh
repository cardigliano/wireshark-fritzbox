#!/bin/bash

EXTCAP_VERSION="0.0.2"
DEFAULT_FRITZ_IFACE="1-lan"
WGET=/usr/local/bin/wget
SID_FILE="/tmp/fritz.sid"

while [ "$1" != "" ]; do
    case $1 in
        --extcap-interfaces)
			echo "extcap {version=$EXTCAP_VERSION}"
			echo "interface {value=remote-fritzbox}{display=Remote FRITZ!Box Capture}"
            shift
            ;;
        --extcap-config)
		    echo "arg {number=0}{call=--ifname}{display=Interface Name}{type=string}{tooltip=FRITZ!Box capture interface }{default=$DEFAULT_FRITZ_IFACE}"  
			#echo "arg {number=0}{call=--ifname}{display=Capture Interface}{type=selector}"
			#echo "value {arg=0}{call=1-lan}{display=LAN}"
			#echo "value {arg=0}{call=2-1}{display=WAN}"
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
        --user)
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

if [ ! -f $SID_FILE ]; then
  touch $SID_FILE
fi

SID=$(cat $SID_FILE)

NOTCONNECTED=$(curl -s "http://$FRITZ_IP/login_sid.lua?sid=$SID" | grep -c "0000000000000000")
if [ $NOTCONNECTED -gt 0 ]; then

  CHALLENGE=$(curl -s http://$FRITZ_IP/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
  HASH=$(perl -MPOSIX -e '
    use Digest::MD5 "md5_hex";
    my $ch_pw = "$ARGV[0]-$ARGV[1]";
    $ch_pw =~ s/(.)/$1 . chr(0)/eg; 
    my $md5 = lc(md5_hex($ch_pw)); 
    print $md5;
  ' -- "$CHALLENGE" "$FRITZ_PWD")
  curl -s "http://$FRITZ_IP/login_sid.lua" -d "response=$CHALLENGE-$HASH" -d 'username='${FRITZ_USER} | grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2 > $SID_FILE
fi

SID=$(cat $SID_FILE)

if [ "$SID" == "0000000000000000" ]; then
  echo "Authentication error" 1>&2
  exit 1
fi

$WGET -qO- http://$FRITZ_IP/cgi-bin/capture_notimeout?ifaceorminor=$FRITZ_IFACE\&snaplen=\&capture=Start\&sid=$SID > $FIFO
