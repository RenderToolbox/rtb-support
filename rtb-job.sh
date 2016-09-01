#!/bin/bash
# Run matlab with given toolboxes and command, and support from environment variables.
#
# Environtment variables for support:
#
# RTB_INPUT_SCRATCH Input scratch folder to create,
# RTB_INPUT_BUCKET S3 bucket to mout at input scratch folder,
# RTB_INPUT_TOPIC ARN of Amazon SNS Topic to use if S3 buket is to be shared.
#
# RTB_OUTPUT_SCRATCH, RTB_OUTPUT_BUCKET, RTB_OUTPUT_TOPIC like INPUT, above.
#
# RTB_STARTUP initialzation script to pass to run('...')
# RTB_TOOLBOXES comma-separated list of toolboxes to pass to tbUse({'...'}),
# RTB_COMMAND command string to pass to matlab -r "..."
#
# 2016 benjamin.heasly@gmail.com


# params and defaults
INPUT_SCRATCH=${RTB_INPUT_SCRATCH:-./rtb-input-scratch}
OUTPUT_SCRATCH=${RTB_OUTPUT_SCRATCH:-./rtb-output-scratch}
COMMAND=${RTB_COMMAND:-ver}

# set up scratch dirs and buckets
function set_up_scratch ()
{
  SCRATCH=$1
  BUCKET=$2
  TOPIC=$3
  
  echo "Create <$SCRATCH>"
  mkdir -p "$SCRATCH"
  
  if [ -n "$BUCKET" ];
  then
    if [ -n "$TOPIC" ];
    then
      echo "Mount Bucket <$BUCKET> at <$SCRATCH> with topic <$TOPIC>"
      yas3fs "$BUCKET" "$SCRATCH" --topic "$TOPIC" --new-queue
    else
      echo "Mount Bucket <$BUCKET> at <$SCRATCH> with no topic"
      yas3fs "$BUCKET" "$SCRATCH"      
    fi
  fi
}

set_up_scratch $INPUT_SCRATCH $RTB_INPUT_BUCKET $RTB_INPUT_TOPIC
set_up_scratch $OUTPUT_SCRATCH $RTB_OUTPUT_BUCKET $RTB_OUTPUT_TOPIC


# build command and call matlab
MATLAB_LOG="$OUTPUT_SCRATCH"/matlab.log
MATLAB_COMMAND="try; run('$RTB_STARTUP'); tbUse({'$RTB_TOOLBOXES'}); $COMMAND; catch err; disp(err); end; exit();"

echo "Call matlab with command <$MATLAB_COMMAND> log to <$MATLAB_LOG>"

# load up-to-date libstdc++, not older version shipped with Matlab
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 matlab -nodisplay -logfile "$MATLAB_LOG" -r "$MATLAB_COMMAND"


# clean up scratch dirs and buckets
function clean_up_scratch ()
{
  SCRATCH=$1
  BUCKET=$2

  if [ -n "$BUCKET" ];
  then
    echo "Unmount Bucket <$BUCKET> at <$SCRATCH>"
    fusermount -u "$SCRATCH"
  fi
}

clean_up_scratch $INPUT_SCRATCH $RTB_INPUT_BUCKET
clean_up_scratch $OUTPUT_SCRATCH $RTB_OUTPUT_BUCKET

