# ninjaben/rtb-support
# 
# Create an image with enough dependencies to support a mounted-in Matlab and RenderToolbox3.
#
# This includes the ability to let Matlab launch Docker containers.  This works by building the Docker
# executable this image, and then mounting in the port to the Docker daemon, from the Docker host. 
#
# In general, the command would look like this:
# docker run --rm \
# -v "$MATLAB_ROOT":/usr/local/MATLAB/from-host \
# -v "$MATLAB_LOGS":/var/log/matlab \
# -v /var/run/docker.sock:/var/run/docker.sock \
# --mac-address="$MATLAB_MAC_ADDRESS" \
# ninjaben/rtb-support -r "system('docker ps');exit;"
#
# Here is a specific example:
# docker run --rm -v "/usr/local/MATLAB/R2016a":/usr/local/MATLAB/from-host -v "/home/ben/Desktop/matlog":/var/log/matlab -v /var/run/docker.sock:/var/run/docker.sock --mac-address="68:f7:28:f6:68:a6" ninjaben/rtb-support -r "system('docker run --rm ninjaben/mitsuba-spectral mitsuba -h');exit;"
#
# Thaks to Jérôme Petazzoni for advice on launching "peer" containers in Docker
#   https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
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

