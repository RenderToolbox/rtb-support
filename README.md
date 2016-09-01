# rtb-support
Docker image with enough dependencies to support a mounted-in Matlab and RenderToolbox3

This image includes dependencies for Matlab and RenderToolbox3.  We should be able to use this image as the basis for scheduling RenderToolbox3 batch jobs, with tools like Kubernetes.

The image does not include Matlab itself, so this must be mounted in from the host.

The image includes the Docker executable, which RenderToolbox3 can use to access renderers, etc.  The idea is that you mount in the port of the Docker daemon from the host.  That way this container can launch Docker containers that are "peers", based on images cached on the host.

# Goals
This is a work in progress.

Want to use Docker containers for two distinct purposes:
 - as the unit of job scheduling with Kubernetes or similar
 - as the way to make dependencies shippable, isolated

Don't want these two purposes to interact.  The images that deal with shipping dependencies should not care that they are being used by a Docker-based scheduler.

At first, this sounds like we want [Docker-in-Docker](https://blog.docker.com/2013/09/docker-can-now-run-within-docker/).  But according to the author, that turns out to be kinda messy and would require changes to the images.  I.e., it would require the two purposes of Docker to know about each other. 

A better way may be to build Docker into one top-level image that we use for job scheduling, and to let contaners from that image share access the Docker daemon on the host.  The same author [explains this](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/).  Then the two purposes for Docker can reemain independent.

# Proof of Concept
I tried this out with Matlab and RenderToolbox3
 - From the host, launch an `rtb-support` container with mounted-in Matlab.
 - In the container, launch Matlab.
 - From Matlab, launch containers like `mitsuba-spectral` to do rendering.

It goes!  The `rtb-support` container and `mitsuba-spectral` containers turn out to be peers, managed by the same Docker daemon on the host.  This is nice because the Docker images are also sitting in the same cache on the host -- there is no "inner" Docker cache that needs to waste time downloading images.

This proof of concept also used an entry point script called `rtb-job.sh`.  This does some setup and invokes Matlab.  It makes it easier to mount support volumes for input and output data files, configure toolboes with ToolboxToolbox, catch matlab errors and still exist, and similar.  It looks for configuration from environment variables, which will help us pass config from Kubernetes or similar.

Here is a command that worked locally, which goes through the motions but just prints Matlab version info:
```
docker run \
  --rm \
  -v "/usr/local/MATLAB/R2016a":/usr/local/MATLAB/from-host \
  -v /home/ben/ToolboxToolbox:/home/ben/ToolboxToolbox \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" 
  ninjaben/rtb-support
```

Here is a similar command that also worked, which did rendering with RenderToolbox3:
```
docker run \
  --rm \
  -v "/usr/local/MATLAB/R2016a":/usr/local/MATLAB/from-host \
  -v /home/ben:/home/ben \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net="host" \
  -e "RTB_STARTUP=/home/ben/Documents/MATLAB/startup" \
  -e "RTB_TOOLBOXES=RenderToolbox3" \
  -e "RTB_COMMAND=rtbTestInstallation" \
  ninjaben/rtb-support
```

Not that bad.

These commands get pretty hairy.  So it will be nice to move the config to yaml for Kubernetes.

# Next
Need to push this further:
 - test with reading/writing data to/from S3
 - test with Kubernetes Job scheduling
 - test with Kubernetes dashboard and S3 web interface
