#!/bin/bash
#
# echo "<youtube id>" | youtube-dl.cr.sh
# youtube-dl.cr.sh < <file with id's>
#
# $1: youtube identifier, or URL
#
# Wrapper for https://github.com/ytdl-org/youtube-dl
#
# Local install required: youtube-dl, eyeD3

DOWNLOAD_FAILED=download.failed.log
TIMESTAMP=''

#
# youtube-dl: Download, convert to mp3, inject thumbnail, set xattr (as reference)
# eyeD3: set MP3 tags
#
function download() {
  local OUT=ytdl.out
 
  [ -z "$1" ] && return
   
  # '--xattrs' only useful to have a reference where the file is from.
#             --metadata-from-title "(?P<artist>.+?) - (?P<title>.+)" 
  youtube-dl -x --restrict-filenames --embed-thumbnail --audio-format mp3 \
             --metadata-from-title "%(artist)s - %(title)s" \
             --youtube-skip-dash-manifest \
             --xattrs "$1" 2>&1 | tee  $OUT

  grep 'ERROR:' $OUT > /dev/null
  if [ $? -eq 0 ] ; then
  
    if [ -z "$TIMESTAMP" ] ; then
      TIMESTAMP=`date "+%d.%m.%Y %H:%M:%S"`
      echo -e "\n$TIMEPSTAMP" >> $DOWNLOAD_FAILED
    fi 
    
    echo "$1" >> $DOWNLOAD_FAILED
    return
  fi

  ARTIST="`grep '\[fromtitle\] parsed artist' $OUT | tr '"' "'" | cut -d ' ' -f 4-`"
  TITLE="`grep '\[fromtitle\] parsed title' $OUT |  tr '"' "'" | cut -d ' ' -f 4-`"
  FILE="`grep '\[ffmpeg\] Destination' $OUT | cut -d ' ' -f 3-`"
  YEAR="`getfattr -n user.dublincore.date $FILE | grep 'user.dublincore.date=' | cut -c23-26`" 

  eyeD3 -t "$TITLE" -A "$TITLE-$ARTIST" -a "$ARTIST" -Y "$YEAR" -n 1 $FILE
  
}

#
# Read yt per line
#
function perLine() {
  # Download if given as file.
  echo "Reading <stdin>"

  while read LINE ; do

    [ -z "$LINE" ] && continue

    set $LINE
    download $1
    
    echo 
  done
}

#
# Main
#

# Check for help
if [ 'x-h' == "x$1" ] ; then 
  echo "Usage: `basename $0` [-h] [youtube id 1] [youtube id n]" 
  echo "       cat yt-id-list.txt | `basename $0`"
  echo "       `basename $0` yt-id-list.txt"
  echo 
  echo "       Failed downloads logged to $DOWNLOAD_FAILED"
  return 0
fi

# Download given as argument?
if [ ! -z "$1" ] ; then

  # Maybe the arg is a file
  if [ -f "$1" ] ; then
    cat "$1" | perLine
    exit 0
  fi

  # Arg is probably given as URL(s) or yt id(s).
  for II in $1; do
    download $II  
  done
  exit 0
fi

# Wait for stdin
perLine
