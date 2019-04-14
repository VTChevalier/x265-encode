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
# This script depends on two separate command line tools:
#
#   HandBrakeCLI    http://handbrake.fr
#   mediainfo       http://mediainfo.sourceforge.net
#
# Usage:
#
#   ./encode.sh [Media File].mkv/mp4/m2ts
#
X264JOB="/tmp/x264.job"
createQueue() {
  if [ -f "$X264JOB".pid ]
  then
    PID=`/bin/cat "$X264JOB".pid`
  fi

  echo $PID
  while [ "$PID" != "" ] && [ -e /proc/$PID ]
  do
    sleep 360 # check hourly
    if [ -f "$X264JOB".pid ]
    then
      PID=`/bin/cat "$X264JOB".pid`
    fi
  done
}

usage() { echo "Usage: $0 -q [Quick Encode] -f MEDIA.MKV" 1>&2; exit 1; }
CURDIR=`pwd`

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

# fine the file no mater where this is run
DIRNAME="`/usr/bin/dirname \"$INFILE\"`"
if [ "$DIRNAME" != "." ]; then
  CURDIR=$DIRNAME
fi

OPTIONS="--markers --encoder x264 --encoder-tune film $TWOPASS --x264-preset $QUALITY"
OPTIONS="$OPTIONS --encopts rc-lookahead=60:b-adapt=2:me=tesa:nal_hrd=vbr:min-keyint=1:keyint=24:bitrate=14020:vbv-maxrate=30000:vbv-bufsize=30000:ratetol=inf"
OPTIONS="$OPTIONS --h264-profile high --h264-level 4.1"
OPTIONS="$OPTIONS -M 709" #compatability
OPTIONS="$OPTIONS -X 1920"
OPTIONS="$OPTIONS --vb 14020"
OPTIONS="$OPTIONS --crop 0:0:0:0 --auto-anamorphic"

# mux HD Audio, AC3 5.1 encode second
OPTIONS="$OPTIONS -a 1,1 -E copy,ffac3" #original audio and ac3 convert

#--subtitle-forced --subtitle-default "
OPTIONS="$OPTIONS --all-subtitles "

OUTFILE="$(/usr/bin/basename \"$INFILE\" | /usr/bin/rev | /usr/bin/cut -f 2- -d '.' | /usr/bin/rev)"
LOGFILE="/tmp/x264-$OUTFILE.log"
INFILE="$CURDIR/`/usr/bin/basename \"$INFILE\"`"
OUTFILE="$CURDIR/$OUTFILE-x264.mkv"

COMMAND=`echo "$HANDBRAKE $OPTIONS --input "\"${INFILE}\"" --output "\"${OUTFILE}\"" > "\"${LOGFILE}\"" 2>&1"`

createQueue

/bin/echo $COMMAND > "$X264JOB"
/bin/echo "rm \"$X264JOB\"" >> "$X264JOB"

/bin/chmod +x "$X264JOB"

/usr/bin/screen -S "Encoding $OUTPUT" -dm `/tmp/x264.job & echo $!  > "$X264JOB".pid` & 

/bin/rm -f "$X264JOB".pid

exit 0;
