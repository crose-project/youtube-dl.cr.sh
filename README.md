# youtube-dl.cr.sh
Small wrapper which uses youtube-dl to download youtube videos, convert to mp3, inject thumbnail, set xattr. Set mp3 tag via eyeD3

Specify yt videos just by their ID or as complete URL.

Usage:

# Direct as argument
youtube.dl.cr.sh <yt id 1> <yt id 2> ...  <yt id n>

# Pipe all yt, one per line, via stdin to script.
cat file-with-yt-ids |  youtube.dl.cr.sh

# Give a file with yt ids
youtube.dl.cr.sh file-with-yt-ids
  

