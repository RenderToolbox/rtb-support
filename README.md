# rtb-support
Docker image with enough dependencies to support a mounted-in Matlab and RenderToolbox3

This image includes dependencies for Matlab and RenderToolbox3.  We should be able to use this image as the basis for scheduling RenderToolbox3 batch jobs, with tools like Kubernetes.

The image does not include Matlab itself, so this must be mounted in from the host.

The image includes the Docker executable, which RenderToolbox3 can use to access renderers, etc.  The idea is that you mount in the port of the Docker daemon from the host.  That way this container can launch Docker containers that are "peers", based on images cached on the host.

This is a work in progress.

When launching containers from this image, we will have to mount in working folders from the host.  I haven't worked that out yet.

Here is a proof of concept command that worked for me.  It does the following:
 - From the host, we launch an `rtb-support` container.
 - In the container, we launch Matlab.
 - In Matlab, we launch a `mitsuba-spectral` container.
 - There two containers are peers.
 - There is still just one Docker daemon and one Docker image cache, on the host.
 - Not that bad!


```
docker run --rm \
  -v "/usr/local/MATLAB/R2016a":/usr/local/MATLAB/from-host \
  -v "/home/ben/Desktop/matlog":/var/log/matlab \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --mac-address="68:f7:28:f6:68:a6" \
  ninjaben/rtb-support -r "system('docker run --rm ninjaben/mitsuba-spectral mitsuba -h');exit;"
```
 
