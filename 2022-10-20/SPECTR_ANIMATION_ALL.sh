#!/bin/bash

if [ -z "$1" ]
then
    echo "Error! Specify source path to process!"
    echo "Usage:"
    echo "    $0 <src path> [<dst path>]"
    exit 1
fi

SRC_PATH="$1"
DST_PATH="$1"

if [[ ! -z "$2" ]]
then
    DST_PATH="$2"
fi

if [ -z "$3" ]
then
    find "$SRC_PATH" -type f -exec "$0" "$SRC_PATH" "$DST_PATH" {} \;
else
    SRC_FILE="$3"
    SRC_FILENAME=`basename "$SRC_FILE"`

    PWD=`dirname $0`

    $PWD/SPECTR_ANIMATION.sh "$SRC_FILE" "$DST_PATH"
fi
