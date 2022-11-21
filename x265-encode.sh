#!/bin/bash
# x265-encode.sh
#
# Copyright (c) 2019 Free Software Foundation, Inc.
# This is free software.  You may redistribute copies of it under the terms of
# the GNU General Public License.
# There is NO WARRANTY, to the extent permitted by law.
#
# Written by Victor T. Chevalier
#
# Usage:
#   ./x265-encode.sh [-a -q] [-f media.mkv/mp4/m2ts]
#
# Bulk files:
#   screen -dm ./x265-encode.sh [-a -q] [-d dir]
#
LOGDIR="/tmp/" # can set this to a specific folder if desired
DIR=""
X265JOB="/tmp/x265.job"
createQueue() {
  if [ -f "$X265JOB".pid ]
  then
    PID=`/bin/cat "$X265JOB".pid`
  fi

  echo $PID
  while [ "$PID" != "" ] && [ -e /proc/$PID ]
  do
    sleep 360 # check hourly
    if [ -f "$X265JOB".pid ]
    then
      PID=`/bin/cat "$X265JOB".pid`
    fi
  done
}

usage() { echo "Usage: $0 -a [anime] -q [quick encode] [-d dir] [-f media.mkv/mp4/m2ts]" 1>&2; exit 1; }
CURDIR=`pwd`

HANDBRAKE=`/usr/bin/which HandBrakeCLI`
MEDIAINFO=`/usr/bin/which mediainfo`
SCREEN=`/usr/bin/which screen`
if [ ! "$HANDBRAKE" ]; then
  echo -e "Please install HandBrakeCLI, sudo apt update && sudo apt install handbrakecli" >&2
  exit 1;
elif [ ! "$MEDIAINFO" ]; then
  echo -e "Please install mediainfo, sudo apt update && sudo apt install mediainfo" >&2
  exit 1;
elif [ ! "$SCREEN" ]; then
  echo -e "Please install screen, sudo apt update && sudo apt install screen" >&2
  exit 1;
fi

# Defaults (Max Quality Encode)
INFILE="0"
#TWOPASS="--two-pass"
#BITRATE="14020"
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
  find "$DIR" -type f -iname \*.mkv |  while read -r dir
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

      `./x265-encode.sh $PASSARGS -f "$dir"`
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

OPTIONS="--markers --encoder x265_10bit"
# if 1920x1080 enhance quality
HDRSPEED="veryslow" 
HDR=""
WIDTH=3840
XSIZE=1920
YSIZE=1080
if [ A$WIDTH == A`$MEDIAINFO -f $INFILE | grep -w Width | grep 3840 | cut -d ':' -f 2 | xargs` ]
then
  HDRSPEED="slower"
  HDR=":hdr10:hdr10-opt"
  XSIZE=3840
  YSIZE=2160
  # HDR->SDR ffmpeg -i 4K.ts -vf zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p -c:v h264 -crf 19 -preset ultrafast output.mp4
fi
HDRSPEED="ultrafast"
QUALITY="16"
QUALITY="50"

OPTIONS="$OPTIONS --encopts selective-sao=0$HDR"
OPTIONS="$OPTIONS -q $QUALITY --encoder-preset $HDRSPEED"
OPTIONS="$OPTIONS -X $XSIZE1920 -Y $YSIZE1080"
OPTIONS="$OPTIONS --crop 0:0:0:0 --auto-anamorphic"

# mux HD Audio, AC3 5.1 encode second
#OPTIONS="$OPTIONS --audio-lang-list eng --all-audio -E copy --audio-copy-mask dtshd,dts,ac3,eac3"
DTSID=`$MEDIAINFO $INFILE "--output=Audio;%ID% %Format% \n" | grep DTS | cut -d ' ' -f 1 | head -1 | xargs`
if [ A$DTSID == A ]
then
  DTSID=`$MEDIAINFO $INFILE "--output=Audio;%ID% %Format% \n" | grep AC-3 | cut -d ' ' -f 1 | head -1 | xargs`
fi
DTSID=`expr $DTSID - 1`

OPTIONS="$OPTIONS -a $DTSID -E copy"
#OPTIONS="$OPTIONS --audio-lang-list eng -a $DTSID -E copy"

# x265 codec specifics
#OPTIONS="$OPTIONS --encopts rc-lookahead=60:b-adapt=2:me=tesa:nal_hrd=vbr:min-keyint=1:keyint=24:bitrate=$BITRATE:vbv-maxrate=30000:vbv-bufsize=30000:ratetol=1.0"
OPTIONS="$OPTIONS --encoder-profile main10"
OPTIONS="$OPTIONS --no-decomb --no-deinterlace"
#OPTIONS="$OPTIONS --vb $BITRATE"

# this preserves subtitles
OPTIONS="$OPTIONS --subtitle-lang-list eng --all-subtitles"
#OPTIONS="$OPTIONS --subtitle scan,1,2,3,4,5,6,7,8,9,10 -a 1,2,3,4,5,6,7,8,9,10"

INFILE="`/usr/bin/basename \"$INFILE\"`"
OUTFILE="$(echo ${INFILE} | /usr/bin/rev | /usr/bin/cut -f 2- -d '.' | /usr/bin/rev)"
LOGFILE="${LOGDIR}x265-$OUTFILE.log"
INFILE="$CURDIR/${INFILE}"
OUTFILE="$CURDIR/$OUTFILE-x265.mkv"

COMMAND=`echo "$HANDBRAKE $OPTIONS --input "\"${INFILE}\"" --output "\"${OUTFILE}\"" > "\"${LOGFILE}\"" 2>&1"`

createQueue

/bin/echo $COMMAND > "$X265JOB"
#/bin/echo "/bin/rm \"$X265JOB\"" >> "$X265JOB"
#/bin/echo "/bin/rm \"$X265JOB\".pid" >> "$X265JOB"
/bin/echo "exit" >> "$X265JOB"

/bin/chmod +x "$X265JOB"

/usr/bin/screen -S "x265 encoding" -dm `/tmp/x265.job & echo $!  > "$X265JOB".pid` & 


exit 0;
