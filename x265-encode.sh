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
OPTIONS="--markers --encoder x265_10bit"
# if 1920x1080 enhance quality
HDRSPEED="veryslow" 
HDR=""
TUNE=""
XSIZE=1920
YSIZE=1080
BITRATE=7010
BITBUFF=40000
THREADS=`lscpu | grep -E '^CPU\(s\)' | cut -d ':' -f 2 | xargs echo`
if [ $THREADS -gt 2 ]
then
  THREADS=`expr $THREADS - 2`
fi
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
    a) TUNE="--encoder-tune animation" BITRATE="2460";;
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

WIDTH=3840
if [ A$WIDTH == A`$MEDIAINFO -f $INFILE | grep -w Width | grep 3840 | cut -d ':' -f 2 | xargs` ]
then
  HDRSPEED="slower"
  HDR=":hdr10:hdr10-opt"
  XSIZE=3840
  YSIZE=2160
  BITRATE=18700
  # HDR->SDR ffmpeg -i 4K.ts -vf zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p -c:v h264 -crf 19 -preset ultrafast output.mp4
  #OPTIONS="$OPTIONS --encopts rc-lookahead=60:b-adapt=2:me=tesa:nal_hrd=vbr:min-keyint=1:keyint=24:bitrate=$BITRATE:vbv-maxrate=30000:vbv-bufsize=30000:ratetol=1.0"
fi
# x265 codec specifics

#HDRSPEED="ultrafast"
QUALITY="16"
VBVBIT=":bitrate=$BITRATE:vbv-maxrate=$BITBUFF:vbv-bufsize=$BITBUFF"
OPTIONS="$OPTIONS --encopts threads=$THREADS:no-sao:selective-sao=0:deblock=-1:-1$HDR$VBVBIT"
OPTIONS="$OPTIONS -q $QUALITY --encoder-preset $HDRSPEED $TUNE"
OPTIONS="$OPTIONS -X $XSIZE -Y $YSIZE"
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

OPTIONS="$OPTIONS --encoder-profile main10 --encoder-level 5.1"
OPTIONS="$OPTIONS --no-decomb --no-deinterlace"
#OPTIONS="$OPTIONS --vb $BITRATE"

# this preserves subtitles
OPTIONS="$OPTIONS --native-language eng --subtitle scan,1,2,3,4,5,6,7,8,9,10 --subtitle-default scan --subtitle-forced scan"
#OPTIONS="$OPTIONS --subtitle-lang-list eng --subtitle scan --subtitle-forced scan --subtitle-default scan --all-subtitles"
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

#@echo off&setlocal
#set "rootfolder=C:\video\test"
#echo Enumerating all MKVs under %rootfolder%
#echo.
#for /r "%rootfolder%" %%a in (*.mkv) do (
#    for /f %%b in ('mkvmerge  --ui-language en -i "%%a" ^| find /c /i "subtitles"') do (
#        if "%%b"=="0" (
#            echo(%%a has no subtitles
#        ) else (
#            echo(%%a has subtitles
#            set "line="
#            for /f "delims=" %%i in ('mkvmerge --ui-language en --identify-verbose "%%a" ^| sed "/subtitles/!d;/language:eng/!d;s/.* \([0-9]*\):.*/\1/"') do (
#                echo(english Track ID: %%i
#                call set line=%%line%% %%i:"%%~dpna (Sub Track %%i).sub"
#            )
#            setlocal enabledelayedexpansion
#            mkvextract tracks "%%a" --ui-language en !line! ||(echo Demuxing error!&goto:eof)
#            endlocal
#            mkvmerge -q -o "%%~dpna (No Subs)%%~xa" -S "%%a"
#            if errorlevel 1 (
#                echo Warnings/errors generated during remuxing, original file not deleted
#            ) else (
#                del /f "%%a"
#                echo Successfully remuxed to "%%~dpna (No Subs)%%~xa", original file deleted
#            )
#            echo(
#        )
#    )
#)

/usr/bin/screen -S "x265 encoding" -dm `/tmp/x265.job & echo $!  > "$X265JOB".pid` & 


exit 0;
