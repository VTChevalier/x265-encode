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
# Usage:
#
#   ./x264-encode.sh [-a -q] [-d dir] [-f media.mkv/mp4/m2ts]
#
DIR=""
X264JOB="/tmp/x264.job.test"
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

usage() { echo "Usage: $0 -a [anime] -q [quick encode] [-d dir] [-f media.mkv/mp4/m2ts]" 1>&2; exit 1; }
CURDIR=`pwd`

HANDBRAKE=`/usr/bin/which HandBrakeCLI`
MEDIAINFO=`/usr/bin/which mediainfo`
if [ ! "$HANDBRAKE" ]; then
  echo -e "Please install HandBrakeCLI, sudo apt update && sudo apt install handbrakecli" >&2
  exit 1;
elif [ ! "$MEDIAINFO" ]; then
  echo -e "Please install mediainfo, sudo apt update && sudo apt install mediainfo" >&2
  exit 1;
fi

# Defaults (Max Quality Encode)
INFILE="0"
TUNE="film"
QUALITY="placebo"
TWOPASS="--two-pass"
BITRATE="14020"
while getopts :hf:d:qa option
do
  case "${option}"
    in
    a) TUNE="animation" BITRATE="4920";;
    d) DIR="${OPTARG}";;
    f) INFILE="${OPTARG}";;
    q) QUALITY="ultrafast" TWOPASS="--no-two-pass";;
    h | *) usage;;
  esac
done

if [ "$DIR" != "" ]; then
  find /mnt/Movies -type f \( -iname \*.mkv -o -iname \*.mp4 -o -iname \*.m2ts\) |  while read -r dir
  do
    if [ -f "$dir" ]; then
      echo "encode $dir"
      PASSARGS=""
      if [ $TUNE == "animation" ]; then
        PASSARGS="-a $PASSARGS"
      fi
      if [ $QUALITY == "ultrafast" ]; then
        PASSARGS="-q $PASSARGS"
      fi

      `./x264-encode.sh $PASSARGS -f "$dir"`
    fi
  done
fi

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

OPTIONS="--markers --encoder x264 --encoder-tune $TUNE $TWOPASS --x264-preset $QUALITY"
OPTIONS="$OPTIONS --encopts rc-lookahead=60:b-adapt=2:me=tesa:nal_hrd=vbr:min-keyint=1:keyint=24:bitrate=$BITRATE:vbv-maxrate=30000:vbv-bufsize=30000:ratetol=1.0"
#OPTIONS="$OPTIONS --h264-profile high --h264-level 4.1"
#OPTIONS="$OPTIONS -M 709" #compatability
OPTIONS="$OPTIONS -X 1920 -Y 1080"
OPTIONS="$OPTIONS --vb $BITRATE"
OPTIONS="$OPTIONS --crop 0:0:0:0 --auto-anamorphic"

# mux HD Audio, AC3 5.1 encode second
OPTIONS="$OPTIONS -a 1,1 -E copy,ffac3" #original audio and ac3 convert

# this preserves subtitles
OPTIONS="$OPTIONS --subtitle scan,1,2,3,4,5,6,7,8,9,10 -a 1,2,3,4,5,6,7,8,9,10"

INFILE="`/usr/bin/basename \"$INFILE\"`"
OUTFILE="$(echo ${INFILE} | /usr/bin/rev | /usr/bin/cut -f 2- -d '.' | /usr/bin/rev)"
LOGFILE="/tmp/x264-$OUTFILE.log"
INFILE="$CURDIR/${INFILE}"
OUTFILE="$CURDIR/$OUTFILE-x264.mkv"

COMMAND=`echo "$HANDBRAKE $OPTIONS --input "\"${INFILE}\"" --output "\"${OUTFILE}\"" > "\"${LOGFILE}\"" 2>&1"`

createQueue

/bin/echo $COMMAND > "$X264JOB"
/bin/echo "/bin/rm \"$X264JOB\"" >> "$X264JOB"
/bin/echo "/bin/rm \"$X264JOB\".pid" >> "$X264JOB"

/bin/chmod +x "$X264JOB"

#/usr/bin/screen -S "x264 encoding" -dm `/tmp/x264.job & echo $!  > "$X264JOB".pid` & 


exit 0;
