# ninjaben/rtb-support
# 
# Create an image with enough dependencies to support a mounted-in Matlab and calling Docker from Matlab.
#
# This includes the ability to let Matlab launch Docker containers.  This works by building the Docker
# executable into this image, and then mounting in the port to the Docker daemon running on the Docker host.
#
# Thaks to Jérôme Petazzoni for advice on this style of launching "peer" containers in Docker
#   https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
#
# Here's an example that runs Matlab in the container, then launches a Docker container from Matlab:
#
# docker run \
#   --rm \
#   -v "/usr/local/MATLAB/R2016a":/usr/local/MATLAB/from-host \
#   -v /var/run/docker.sock:/var/run/docker.sock \
#   --net="host" \
#   -e "COMMAND=system('docker run hello-world')" \
#   ninjaben/rtb-support"
#
# The entrypoint is the included script rtb-job.sh.  This script can handle additoinal details that we need for
# running Matlab jobs on AWS, including:
#   - toolbox setup with the ToolboxToolbox tbUse
#   - mounting an S3 bucket for input data
#   - mounting an s3 bucket for output data
#
# To set these things up, the script reads configuration from environment variables.  These can be passed to the
# Docker container with "-e".
#

FROM ninjaben/matlab-support

MAINTAINER Ben Heasly <benjamin.heasly@gmail.com>

# general dependencies
RUN apt-get update && apt-get install -y \
    git \
    docker.io \
    libboost-all-dev \
    openexr \
    cmake \
    pkg-config

# Assimp
WORKDIR /assimp
RUN git clone https://github.com/assimp/assimp.git
WORKDIR /assimp/assimp
RUN git checkout v3.3.1
RUN cmake CMakeLists.txt -G 'Unix Makefiles' && make && make install && ldconfig

# yas3fs
RUN apt-get install -y \
    fuse \
    python-pip
RUN pip install yas3fs
RUN sed -i'' 's/^# *user_allow_other/user_allow_other/' /etc/fuse.conf
RUN chmod a+r /etc/fuse.conf

# job helper
WORKDIR /rtb
COPY rtb-job.sh /rtb/
ENTRYPOINT ["/rtb/rtb-job.sh"]

