#!/bin/bash
 
date=`date '+%Y%m%d_%H%M'`
cachedir=/var/cache/radiko/
mp3dir=/mnt/storage/share/radio/
playerurl=http://radiko.jp/player/swf/player_3.0.0.01.swf
playerfile="./player.swf"
keyfile="./authkey.png"
tmpfile="./${1}_${date}"
mp3file="${mp3dir}${1}_${date}.mp3"
 
if [ $# -ge 2 ]; then
  station=$1
  DURATION=`expr $2 \* 60`
  if [ $# -eq 3 ]; then
    delaysec=$3
  else
    delaysec=0
  fi
else
  echo "usage : radiorec station_name duration(minuites) [offset(sec)]"
  exit 1
fi
 
cd $cachedir
 
#
# get player
#
if [ ! -f $playerfile ]; then
  wget -q -O $playerfile $playerurl
 
  if [ $? -ne 0 ]; then
    echo "failed get player"
    exit 1
  fi
fi
 
#
# get keydata (need swftool)
#
if [ ! -f $keyfile ]; then
  swfextract -b 14 $playerfile -o $keyfile
 
  if [ ! -f $keyfile ]; then
    echo "failed get keydata"
    exit 1
  fi
fi
 
if [ -f auth1_fms ]; then
  rm -f auth1_fms
fi
 
#
# access auth1_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --post-data='\r\n' \
     --no-check-certificate \
     --save-headers \
     https://radiko.jp/v2/api/auth1_fms
 
if [ $? -ne 0 ]; then
  echo "failed auth1 process"
  exit 1
fi
 
#
# get partial key
#
authtoken=`perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)' auth1_fms`
offset=`perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)' auth1_fms`
length=`perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)' auth1_fms`
 
partialkey=`dd if=$keyfile bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey:
 
$partialkey"
 
rm -f auth1_fms
 
if [ -f auth2_fms ]; then
  rm -f auth2_fms
fi
 
#
# access auth2_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-Authtoken: ${authtoken}" \
     --header="X-Radiko-Partialkey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     https://radiko.jp/v2/api/auth2_fms
 
if [ $? -ne 0 -o ! -f auth2_fms ]; then
  echo "failed auth2 process"
  exit 1
fi
 
echo "authentication success"
areaid=`perl -ne 'print $1 if(/^([^,]+),/i)' auth2_fms`
echo "areaid: $areaid"
 
rm -f auth2_fms
 
# offset time
echo "Sleep ${delaysec} sec."
sleep $delaysec
 
#
# rtmpdump
#
/usr/local/bin/rtmpdump -v \
         -r "rtmpe://w-radiko.smartstream.ne.jp" \
         --playpath "simul-stream.stream" \
         --app "${station}/_definst_" \
         -W $playerurl \
         -C S:"" -C S:"" -C S:"" -C S:$authtoken \
         --live \
         --stop $DURATION \
         -o $tmpfile
 
# /usr/local/bin/ffmpeg -y -i $tmpfile -acodec libmp3lame -ab 64k $mp3file
 
# rm $tmpfile

