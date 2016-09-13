#! /bin/bash

# A few tests for rtb-job.sh.
# Have to read output to verify it works (sorry).
# Have to set up some local env as fixture (sorry).

HOST_MATLAB="/usr/local/MATLAB/R2016a"
HOST_VOLUME="/home/ben/"
HOST_STARTUP="/home/ben/Documents/MATLAB/startup"
HOST_AWS="/home/ben/.aws"

INPUT_BUCKET="s3://render-toolbox-test/input"
INPUT_TOPIC="arn:aws:sns:us-east-1:547825153113:render-toolbox-test-input-topic"
OUTPUT_BUCKET="s3://render-toolbox-test/output"
OUTPUT_TOPIC="arn:aws:sns:us-east-1:547825153113:render-toolbox-test-output-topic"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

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

# make sure we can read and write S3 buckets eagerly
# gosh, the buckets take a lot of config
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" \
  --cap-add SYS_ADMIN \
  --cap-add MKNOD \
  --device=/dev/fuse \
  --security-opt apparmor:unconfined \
  -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
  -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
  -e "INPUT_SCRATCH=/test/input-scratch" \
  -e "INPUT_BUCKET=$INPUT_BUCKET" \
  -e "INPUT_DIRECT_MOUNT=false" \
  -e "OUTPUT_SCRATCH=/test/output-scratch" \
  -e "OUTPUT_BUCKET=$OUTPUT_BUCKET" \
  -e "OUTPUT_DIRECT_MOUNT=false" \
  -e "COMMAND=system('cat /test/input-scratch/test-input.txt && echo $RANDOM | tee /test/output-scratch/test-output.txt')" \
  ninjaben/rtb-support

# make sure we can read and write S3 buckets lazily
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" \
  --cap-add SYS_ADMIN \
  --cap-add MKNOD \
  --device=/dev/fuse \
  --security-opt apparmor:unconfined \
  -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
  -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
  -e "INPUT_SCRATCH=/test/input-scratch" \
  -e "INPUT_BUCKET=$INPUT_BUCKET" \
  -e "INPUT_DIRECT_MOUNT=true" \
  -e "OUTPUT_SCRATCH=/test/output-scratch" \
  -e "OUTPUT_BUCKET=$OUTPUT_BUCKET" \
  -e "OUTPUT_DIRECT_MOUNT=true" \
  -e "COMMAND=system('cat /test/input-scratch/test-input.txt && echo $RANDOM | tee /test/output-scratch/test-output.txt')" \
  ninjaben/rtb-support

# make sure we can use AWS SNS topics, in case we're sharing a bucket
docker run \
  --rm \
  -v $HOST_MATLAB:/usr/local/MATLAB/from-host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" \
  --cap-add SYS_ADMIN \
  --cap-add MKNOD \
  --device=/dev/fuse \
  --security-opt apparmor:unconfined \
  -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
  -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
  -e "INPUT_SCRATCH=/test/input-scratch" \
  -e "INPUT_BUCKET=$INPUT_BUCKET" \
  -e "INPUT_DIRECT_MOUNT=true" \
  -e "INPUT_TOPIC=$INPUT_TOPIC" \
  -e "OUTPUT_SCRATCH=/test/output-scratch" \
  -e "OUTPUT_BUCKET=$OUTPUT_BUCKET" \
  -e "OUTPUT_DIRECT_MOUNT=true" \
  -e "OUTPUT_TOPIC=$OUTPUT_TOPIC" \
  -e "COMMAND=system('cat /test/input-scratch/test-input.txt && echo $RANDOM | tee /test/output-scratch/test-output.txt')" \
  ninjaben/rtb-support

