#!/bin/bash

FREQ_SRC=48000
FREQ_LIMIT=2000
#WINDOW_SIZE=16536
#WINDOW_SIZE=32768
WINDOW_SIZE=65536
WINDOW_STEP=1920
FFT_APP=/usr/local/src/2022-10-18/window_slicing

if [ -z "$1" ]
then
    echo "Error! Specify media file!"
    echo "Usage:"
    echo "    $0 <media file>"
    exit 1
fi

if [[! -f "$0" ]]
then
    echo "Error! File [$1] does not exist"
    exit 1
fi

TMP_PATH=`mktemp -d`
echo "Temp dir [$TMP_PATH]"

SRC_FILE="$1"
DST_FILE="${SRC_FILE}.SPECTR_ANIMATION.mp4"

# override dst path
if [[ ! -z "$2" ]]
then
    FILENAME=`basename "$1"`
    DST_FILE="$2/${FILENAME}.SPECTR_ANIMATION.mp4"
fi

# demux wav file
DST_WAV="$TMP_PATH/wav"
ffmpeg -i "$SRC_FILE" -vn -f wav -y "$DST_WAV"

# create raw file
DST_RAW="$TMP_PATH/raw"
ffmpeg -i "$DST_WAV" -ar "$FREQ_SRC" -ac 1 -f s16le -y "$DST_RAW"

# create spectr file
DST_LOG="$TMP_PATH/log"
"$FFT_APP" $FREQ_SRC $FREQ_LIMIT $WINDOW_SIZE $WINDOW_STEP "$DST_RAW" > "$DST_LOG"

# read log for each frame
SRC_FILENAME=`basename "$1"`
CURR_TIME_POS=""
CURR_FILE=""
SEQ_NUM=0
SEQ_PATH="$TMP_PATH/seq"
mkdir -p "$SEQ_PATH"
PLOT_FILE="$TMP_PATH/plot"
LOG_FILE="$TMP_PATH/curr"

echo "processing [$DST_LOG]"
while IFS=$'\t' read -r -a Columns
do
    # check if time changed
    if [ "$CURR_TIME_POS" != "${Columns[0]}" ]
    then
        # assign new time
        CURR_TIME_TRG="$CURR_TIME_POS"
        CURR_TIME_POS="${Columns[0]}"
        echo "new CURR_TIME_POS=[$CURR_TIME_POS]"

        # check if current file is not empty
        if [[ ! -z "$CURR_FILE" ]]
        then
            PLOT_FILE="$CURR_FILE.plot"

            # increment image seq counter counter
            printf -v SEQ_FMT '%05d' $SEQ_NUM
            SEQ_NUM=$((SEQ_NUM+1))

            # run building plot file
            echo "building plot [$PLOT_FILE]"
            echo "#!/usr/bin/gnuplot -persist" > "$PLOT_FILE"
            echo "" >> "$PLOT_FILE"
            echo "set terminal png size 1920,1080 font \"/TheCore/fonts/tahoma.ttf\"" >> "$PLOT_FILE"
            echo "set output \"$SEQ_PATH/$SEQ_FMT.png\"" >> "$PLOT_FILE"
            echo "set title \"[$CURR_TIME_TRG] $SRC_FILENAME\"" >> "$PLOT_FILE"
            echo "plot \"$CURR_FILE\" with lines" >> "$PLOT_FILE"

            # run building png
            chmod +x "$PLOT_FILE"
            "$PLOT_FILE"

            # remove old file
#            rm -f "$CURR_FILE"
        fi

        # generate new filename
        printf -v SEQ_FMT1 '%05d' $SEQ_NUM
        CURR_FILE="$TMP_PATH/$SEQ_FMT1.log"
    fi

    echo -e "${Columns[1]}\t${Columns[2]}" >> $CURR_FILE
done < "$DST_LOG"

# compose mp4 file
ffmpeg -r $FREQ_SRC/$WINDOW_STEP \
    -i "$SEQ_PATH/%05d.png" \
    -i "$DST_WAV" \
    -c:v libx264 -pix_fmt yuv420p -crf 24 \
    -f mp4 -movflags +faststart \
    -shortest \
    -y "$DST_FILE"

# cleanup
rm -f -r -r "$TMP_PATH"
