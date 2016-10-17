#! /bin/bash

# A few tests for rtb-job.sh.
# Have to read output to verify it works (sorry).
# Have to set up some local env as fixture (sorry).

HOST_MATLAB="/usr/local/MATLAB/R2016a"
HOST_VOLUME="$HOME"
HOST_STARTUP="$HOME/Documents/MATLAB/startup"
HOST_AWS_CONFIG="$HOME/.aws/config"

INPUT_BUCKET="s3://render-toolbox-test/input"
OUTPUT_BUCKET="s3://render-toolbox-test/output"


# make sure we can run Docker from in Matlab
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" \
  -e "COMMAND=system('docker run hello-world')" \
  ninjaben/rtb-support


# make sure we can find ToolboxToolbox from host
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOST_VOLUME:$HOST_VOLUME \
  --net="host" \
  -e "STARTUP=$HOST_STARTUP" \
  -e "TOOLBOXES='sample-repo'" \
  -e "COMMAND=which('master.txt')" \
  ninjaben/rtb-support


# make sure we can read and write S3 buckets
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOST_VOLUME:$HOST_VOLUME \
  --net="host" \
  -e "AWS_CONFIG_FILE=$HOST_AWS_CONFIG" \
  -e "INPUT_SCRATCH=/test/input-scratch" \
  -e "INPUT_BUCKET=$INPUT_BUCKET" \
  -e "OUTPUT_SCRATCH=/test/output-scratch" \
  -e "OUTPUT_BUCKET=$OUTPUT_BUCKET" \
  -e "COMMAND=system('cat /test/input-scratch/test-input.txt && echo $RANDOM | tee /test/output-scratch/test-output.txt')" \
  ninjaben/rtb-support
  
  # make sure we can mount an s3 bucket
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOST_VOLUME:$HOST_VOLUME \
  --cap-add SYS_ADMIN \
  --cap-add MKNOD \
  --device=/dev/fuse \
  --security-opt apparmor:unconfined \
  --net="host" \
  -e "AWS_CONFIG_FILE=$HOST_AWS_CONFIG" \
  -e "MOUNT_SCRATCH=/test/input-scratch" \
  -e "MOUNT_BUCKET=$INPUT_BUCKET" \
  -e "OUTPUT_SCRATCH=/test/output-scratch" \
  -e "OUTPUT_BUCKET=$OUTPUT_BUCKET" \
  -e "COMMAND=system('cat /test/input-scratch/test-input.txt && echo $RANDOM | tee /test/output-scratch/test-output.txt')" \
  ninjaben/rtb-support


