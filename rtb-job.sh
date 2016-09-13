#!/bin/bash
# Run matlab with given toolboxes and command, and support from environment variables.
#
# Environtment variables for support:
#
# STARTUP initialzation script invoke as run('$STARTUP') (single quotes added for you)
# TOOLBOXES arguments to pass to tbUse($TOOLBOXES) (no quotes added)
# COMMAND command string to pass to matlab -r "..."
#
# INPUT_SCRATCH Input scratch folder to create
# INPUT_BUCKET S3 bucket to mout for input scratch folder
# INPUT_TOPIC ARN of Amazon SNS Topic to use if input bucket is to be shared
# INPUT_DIRECT_MOUNT if true (default) directly mounts the INPUT_BUCKET at INPUT_SCRATCH,
#                    otherwise mounts to /tmp, copies data to INPUT_SCRATCH, then unmounts
#
# OUTPUT_SCRATCH Output scratch folder to create
# OUTPUT_BUCKET S3 bucket to mout for output scratch folder
# OUTPUT_TOPIC ARN of Amazon SNS Topic to use if output bucket is to be shared
# OUTPUT_DIRECT_MOUNT if true directly mounts the OUTPUT_BUCKET at OUTPUT_SCRATCH,
#                     otherwise (default) mounts to /tmp, copies data from OUTPUT_SCRATCH, then unmounts
#
# INPUT_DIRECT_MOUNT and OUTPUT_DIRECT_MOUNT decide when to read/write data from/to S3 buckets.  This 
# matters because S3 access goes through a REST API, and might be slow.
#
# For input data, the default behavior is to directly mount INPUT_BUCKET at INPUT_SCRATCH 
# (ie  INPUT_DIRECT_MOUNT=true).  This lets the job read input data lazily/when needed, which seems sane 
# especially if the job might not read to read the whole bucket.
#
# For output data, the default is to let the job write to OUTPUT_SCRATCH with no bucket mounted, then afterwards 
# (ie OUTPUT_DIRECT_MOUNT=false), then afterwards mount OUTPUT_BUCKET to /tmp can copy over all the data from
# OUTPUT_SCRATCH.  This seems sane since it lets the job run without depending on the slow S3 API, but we
# still want to collect all the output data that was produced.
#
# 2016 benjamin.heasly@gmail.com


# given or default environment
: ${STARTUP:=""}
: ${TOOLBOXES:=""} 
: ${COMMAND:="ver"}

: ${INPUT_SCRATCH:="/input-scratch"}
: ${INPUT_BUCKET:=""}
: ${INPUT_TOPIC:=""}
: ${INPUT_DIRECT_MOUNT:="true"}
: ${INPUT_TEMP:=`mktemp -d /tmp/input-temp-XXXXXXXXXX`}

: ${OUTPUT_SCRATCH:="/output-scratch"}
: ${OUTPUT_BUCKET:=""}
: ${OUTPUT_TOPIC:=""}
: ${OUTPUT_DIRECT_MOUNT:="false"}
: ${OUTPUT_TEMP:=`mktemp -d /tmp/output-temp-XXXXXXXXXX`}


# set up scratch dirs and buckets
function set_up_scratch ()
{
  SCRATCH=$1
  BUCKET=$2
  TOPIC=$3
  TEMP=$4
  DIRECT_MOUNT=$5
  
  echo "Create <$SCRATCH>"
  mkdir -p "$SCRATCH"
  
  if [ -n "$BUCKET" ];
  then
    if [ "$DIRECT_MOUNT" == "true" ];
    then
      if [ -n "$TOPIC" ];
      then
        echo "Mount Bucket <$BUCKET> at <$SCRATCH> with topic <$TOPIC>"
        yas3fs "$BUCKET" "$SCRATCH" --topic "$TOPIC" --new-queue --cache-entries 0 --cache-mem-size 0 --cache-disk-size 0 --s3-num 0
      else
        echo "Mount Bucket <$BUCKET> at <$SCRATCH> with no topic"
        yas3fs "$BUCKET" "$SCRATCH"      
      fi
    elif [ -n "$TEMP" ]
    then
      echo "Mount Bucket <$BUCKET> at <$TEMP>, copy to <$SCRATCH>"
      yas3fs "$BUCKET" "$TEMP" --cache-entries 0 --cache-mem-size 0 --cache-disk-size 0 --s3-num 0
      cp -rf "$TEMP"/* "$SCRATCH/"
      fusermount -u "$TEMP"
    fi
  fi
}

set_up_scratch "$INPUT_SCRATCH" "$INPUT_BUCKET" "$INPUT_TOPIC" "$INPUT_TEMP" "$INPUT_DIRECT_MOUNT"
set_up_scratch "$OUTPUT_SCRATCH" "$OUTPUT_BUCKET" "$OUTPUT_TOPIC" "" "$OUTPUT_DIRECT_MOUNT"


# build command and call matlab
MATLAB_LOG="$OUTPUT_SCRATCH"/matlab.log
MATLAB_COMMAND="try; run('$STARTUP'); if exist('tbUse', 'file'); tbUse($TOOLBOXES); end; $COMMAND; catch err; disp(err); end; exit();"


# invoke Matlab with up-to-date libstdc++, not older version shipped with Matlab
echo "Call matlab with command <$MATLAB_COMMAND> log to <$MATLAB_LOG>"
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 matlab -nodisplay -logfile "$MATLAB_LOG" -r "$MATLAB_COMMAND"


# clean up scratch dirs and buckets
function clean_up_scratch ()
{
  SCRATCH=$1
  BUCKET=$2
  TEMP=$3
  DIRECT_MOUNT=$4

  if [ -n "$BUCKET" ];
  then
    if [ "$DIRECT_MOUNT" == "true" ];
    then
      echo "Unmount Bucket <$BUCKET> at <$SCRATCH>"
      fusermount -u "$SCRATCH"
    elif [ -n "$TEMP" ]
    then
      echo "Mount Bucket <$BUCKET> at <$TEMP>, copy from <$SCRATCH>"
      yas3fs "$BUCKET" "$TEMP" --cache-entries 0 --cache-mem-size 0 --cache-disk-size 0 --s3-num 0
      cp -rf "$SCRATCH"/* "$TEMP/"
      fusermount -u "$TEMP"
    fi
  fi
}

clean_up_scratch "$INPUT_SCRATCH" "$INPUT_BUCKET" "" "$INPUT_DIRECT_MOUNT"
clean_up_scratch "$OUTPUT_SCRATCH" "$OUTPUT_BUCKET" "$OUTPUT_TEMP" "$OUTPUT_DIRECT_MOUNT"

