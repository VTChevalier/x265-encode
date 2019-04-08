#!/bin/bash
#
# /usr/local/bin/x264-encode.sh
#
# Copyright (c) 2019 Free Software Foundation, Inc.
# This is free software.  You may redistribute copies of it under the terms of
# the GNU General Public License.
# There is NO WARRANTY, to the extent permitted by law.
#
# Written by Victor T. Chevalier
#
# Designed for use with openvpn on Ubuntu 18.04/16.04 LTS
#
# This script depends on two separate command line tools:
#
#   HandBrakeCLI    http://handbrake.fr
#   mediainfo       http://mediainfo.sourceforge.net
#
# Usage:
#
#   ./encode.sh [Media File].mkv/mp4/m2ts
#
usage() { echo "Usage: $0 -q [Quick Encode] -f MEDIA.MKV" 1>&2; exit 1; }

HANDBRAKE=`/usr/bin/which HandBrakeCLI`
MEDIAINFO=`/usr/bin/which mediainfo`
if [ ! "$HANDBRAKE" ]; then
  echo -e "Please install HandBrakeCLI, http://handbrake.fr" >&2
  exit 1;
elif [ ! "$MEDIAINFO" ]; then
  echo -e "Please install mediainfo, http://mediainfo.sourceforge.net" >&2
  exit 1;
fi

# Defaults (Max Quality Encode)
INFILE="0"
QUALITY="placebo"
TWOPASS="--two-pass"
while getopts :hf:q option
do
  case "${option}"
    in
    f) INFILE=${OPTARG};;
    q) QUALITY="ultrafast" TWOPASS="--no-two-pass";;
    h | *) usage;;
  esac
done

if [ "$INFILE" == "0" ]; then
  usage
elif [ ! -f "$INFILE" ]; then
  echo -e "File not found." >&2
  exit 1;
fi

OPTIONS="--markers --encoder x264 --encoder-tune film $TWOPASS --x264-preset $QUALITY"
OPTIONS="$OPTIONS --encopts rc-lookahead=60:b-adapt=2:me=tesa:nal_hrd=vbr:min-keyint=1:keyint=24:bitrate=14020:vbv-maxrate=30000:vbv-bufsize=30000:ratetol=inf"
OPTIONS="$OPTIONS --h264-level 4.1"
OPTIONS="$OPTIONS --vb 14020"
OPTIONS="$OPTIONS --crop 0:0:0:0 --auto-anamorphic"

# mux HD Audio, AC3 5.1 encode second
OPTIONS="$OPTIONS -a 1,1 -E copy,ffac3" #original audio and ac3 convert

#--subtitle-forced --subtitle-default "
OPTIONS="$OPTIONS --all-subtitles "

OUTFILE="$(/bin/echo $INFILE | /usr/bin/rev | /usr/bin/cut -f 2- -d '.' | /usr/bin/rev)"
LOGFILE="/tmp/$OUTFILE.log"
OUTFILE="$OUTFILE-x264.mkv"

echo -e "Encoding: $INFILE"

`/usr/bin/screen -d -m "$HANDBRAKE $OPTIONS --input "$INFILE" --output "$OUTFILE" 2>&1 | /usr/bin/tee -a "$LOGFILE"`

exit 0;