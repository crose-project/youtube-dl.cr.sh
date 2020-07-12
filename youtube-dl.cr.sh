#!/bin/bash
#
# echo "<youtube id>" | youtube-dl.cr.sh
# youtube-dl.cr.sh < <file with id's>
#
# $1: youtube identifier, or URL
#
# Wrapper for https://github.com/ytdl-org/youtube-dl
#
# Local install required: youtube-dl, eyed3, webp (provides: dwebp)

DOWNLOAD_FAILED=.ytdl.download.failed.log
TIMESTAMP=''

#
# youtube-dl: Download, convert to mp3, inject thumbnail, set xattr (as reference)
# eyeD3: set MP3 tags
#
function download() {
  local OUT=.ytdl.out
 
  [ -z "$1" ] && return
   
  # '--xattrs' only useful to have a reference where the file is from.
  #             --metadata-from-title "(?P<artist>.+?) - (?P<title>.+)" 
  
  # CR 26.6.20: removed '--embed-thumbnail' cause the YT webp image can't be handled by youtube-dl. 
  # Also it's better to scale down the thumbnail fix to 400px width to limit filesize.
  youtube-dl -x --restrict-filenames --audio-format mp3 \
             --write-thumbnail \
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
  
  FILE="`grep '\[ffmpeg\] Destination' $OUT | cut -d ' ' -f 3-`"
  YEAR="`getfattr -n user.dublincore.date $FILE | grep 'user.dublincore.date=' | cut -c23-26`" 
  
  grep 'Could not interpret title of video as' $OUT > /dev/null
  if [ $? -eq 0 ] ; then
    # Title could not be splitted: take everything upto first '-'. Example: Syria_Original-lmbY--Br7B4.mp3
    ARTIST="`echo "$FILE" | cut -d '-' -f 1`"
    TITLE="$ARTIST"
  else
    ARTIST="`grep '\[fromtitle\] parsed artist' $OUT | tr '"' "'" | cut -d ' ' -f 4-`"
    TITLE="`grep '\[fromtitle\] parsed title' $OUT |  tr '"' "'" | cut -d ' ' -f 4-`"
  fi  
  
  doThumbnail $FILE

  eyeD3 -t "$TITLE" -A "$TITLE-$ARTIST" -a "$ARTIST" -Y "$YEAR" --add-image=thumbnail.jpg:OTHER -n 1 $FILE
  
  rm thumbnail.jpg
}

#
# doThumbnail()
#
# Convert webp to png. 
# Convert gif png jpg tif to thumbnail.jpg with width=400
# Result is always: thumbnail.jpg
#
function doThumbnail() {

  local FILE="$1"

  # IM can't convert WEBP: convert to PNG first.
  [ -r "${FILE%.*}.webp" ] && dwebp "${FILE%.*}.webp" -o ${FILE%.*}.png && rm "${FILE%.*}.webp"

  # Check for all image types: resize and convert to JPG/400px. Target is always 'thumbnail.jpg'
  for II in gif png jpg tif ; do
    [ -r "${FILE%.*}.$II" ] && convert "${FILE%.*}.${II}[400x>]" thumbnail.jpg && rm "${FILE%.*}.${II}"
  done
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

