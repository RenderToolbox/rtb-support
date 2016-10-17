#!/bin/bash
# Run matlab with given toolboxes and command, and support from environment variables.
#
# Environtment variables for support:
#
# STARTUP initialzation script invoke as run('$STARTUP') (single quotes added for you)
# TOOLBOXES arguments to pass to tbUse($TOOLBOXES) (no quotes added)
# COMMAND command string to pass to matlab -r "..."
#
# INPUT_SCRATCH Input scratch folder to create before running COMMAND
# INPUT_BUCKET S3 bucket copy into INPUT_SCRATCH before running COMMAND
# INPUT_FLAGS flags to pass to "aws s3 cp ...", default is "--recursive"
#
# OUTPUT_SCRATCH Output scratch folder to create before running COMMAND
# OUTPUT_BUCKET S3 bucket to receive data from OUTPUT_SCRATCH after running COMAND
# OUTPUT_FLAGS flags to pass to "aws s3 cp ...", default is "--recursive"
#
# MOUNT_SCRATCH Scratch folder to create where an S3 bucket can be mounted
# MOUNT_BUCKET S3 bucket mount at MOUNT_SCRATCH before running COMMAND
# MOUNT_FLAGS flags to pass to "yas3fs ...", default is "", no special flags
#
# Note on mounting buckets: it's good for reading input data from a bucket,
# especially for lazy reads where we want to avoid copying the whole bucket.
# It's not so good for writing output data because the job might terminate
# before the write finishes.  OUTPUT_BUCKET is better for writing.
#
# 2016 benjamin.heasly@gmail.com


# given or default environment
: ${STARTUP:=""}
: ${TOOLBOXES:="''"} 
: ${COMMAND:="ver"}

: ${INPUT_SCRATCH:="/input-scratch"}
: ${INPUT_BUCKET:=""}
: ${INPUT_FLAGS:="--recursive"}

: ${OUTPUT_SCRATCH:="/output-scratch"}
: ${OUTPUT_BUCKET:=""}
: ${OUTPUT_FLAGS:="--recursive"}

: ${MOUNT_SCRATCH:="/mount-scratch"}
: ${MOUNT_BUCKET:=""}
: ${MOUNT_FLAGS:=""}


# util to move data to/from s3
function copy_data ()
{
  SOURCE=$1
  DESTINATION=$2
  FLAGS=$3
  
  if [ -n "$SOURCE" ] && [ -n "$DESTINATION" ];
  then
    echo "Copy <$SOURCE> to <$DESTINATION>"
    aws s3 cp "$SOURCE" "$DESTINATION" "$FLAGS"
  fi
}


# util to mount an S3 bucket
function mount_bucket ()
{
  BUCKET=$1
  SCRATCH=$2
  FLAGS=$3
  
  if [ -n "$BUCKET" ] && [ -n "$SCRATCH" ];
  then
    echo "Mount bucket <$BUCKET> at <$SCRATCH>"
    yas3fs "$BUCKET" "$SCRATCH" "$FLAGS"
  fi
}


# util to unmount an S3 bucket
function unmount_bucket ()
{
  BUCKET=$1
  SCRATCH=$2
  
  if [ -n "$BUCKET" ] && [ -n "$SCRATCH" ];
  then
    echo "Unount bucket <$BUCKET> at <$SCRATCH>"
    fusermount -u "$SCRATCH"
  fi
}


# want scratch dirs to exist
echo "Create <$INPUT_SCRATCH>, <$OUTPUT_SCRATCH>, and<$MOUNT_SCRATCH>"
mkdir -p "$INPUT_SCRATCH"
mkdir -p "$OUTPUT_SCRATCH"
mkdir -p "$MOUNT_SCRATCH"


# mount the bucket
mount_bucket "$MOUNT_SCRATCH" "$MOUNT_SCRATCH" "$MOUNT_FLAGS"


# read data from input bucket
copy_data "$INPUT_BUCKET" "$INPUT_SCRATCH" "$INPUT_FLAGS"


# build command and call matlab
MATLAB_LOG="$OUTPUT_SCRATCH"/matlab.log
MATLAB_COMMAND="try; run('$STARTUP'); if exist('tbUse', 'file'); tbUse($TOOLBOXES); end; $COMMAND; catch err; disp(err); end; save(fullfile('$OUTPUT_SCRATCH', sprintf('rtb-job-%s', datestr(now(), 30)))); exit();"


# invoke Matlab with up-to-date libstdc++, not older version shipped with Matlab
echo "Call matlab with command <$MATLAB_COMMAND> log to <$MATLAB_LOG>"
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 matlab -nodisplay -logfile "$MATLAB_LOG" -r "$MATLAB_COMMAND"


# write data to output bucket
copy_data "$OUTPUT_SCRATCH" "$OUTPUT_BUCKET" "$OUTPUT_FLAGS"


# unmount scratch bucket
unmount_bucket "$MOUNT_SCRATCH" "$MOUNT_SCRATCH"
