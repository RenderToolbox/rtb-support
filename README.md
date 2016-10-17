# rtb-support
Docker image with enough dependencies to support a mounted-in Matlab and RenderToolbox

This image includes dependencies for Matlab and RenderToolbox.  We should be able to use this image as the basis for scheduling RenderToolbox batch jobs, with tools like Kubernetes.

The image does not include Matlab itself, so this must be mounted in from the host.

The image includes the Docker executable, which RenderToolbox can use to access renderers, etc.  The idea is that you mount in the port of the Docker daemon from the host.  That way this container can launch Docker containers that are "peers", based on images cached on the host.

The image entrypoint is [rtb-job.sh](https://github.com/RenderToolbox/rtb-support/blob/master/docker/rtb-job.sh).  This will copy input data from an S3 bucket, run Matlab with a startup command, toolbox setup and an arbitrary command, then copy output data to an S3 bucket.  The commands and other config come from environment variables (ie docker run -e ...).

# Uses of Docker

Want to use Docker containers for two distinct purposes:
 - as the unit of job scheduling with Kubernetes or similar
 - as the way to make dependencies shippable, isolated

Don't want these two purposes to interact.  The images that deal with shipping dependencies should not care that they are being used by a Docker-based scheduler.

At first, this sounds like we want [Docker-in-Docker](https://blog.docker.com/2013/09/docker-can-now-run-within-docker/).  But according to the author, that turns out to be kinda messy and would require changes to the images.  I.e., it would require the two purposes of Docker to know about each other. 

A better way may be to build Docker into one top-level image that we use for job scheduling, and to let contaners from that image share access the Docker daemon on the host.  The same author [explains this](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/).  Then the two purposes for Docker can reemain independent.

# Progress
This is a work in progress.

Here are some usage examples I'm working with:
 - [rtb-job-dev-test.sh](https://github.com/RenderToolbox/rtb-support/blob/master/test/rtb-job-dev-test.sh) has examples of running the Docker image locally.
 - [run-render-instance](https://github.com/RenderToolbox/rtb-support/blob/master/client/run-render-instance) is a bash script to start an EC2 instance based on a suitable, private AMI, run a command, then terminate the instance.
 - [rtb-suppor-client-test](https://github.com/RenderToolbox/rtb-support/blob/master/test/rtb-suppor-client-test) combines the two, to do a RenderToolbox test in a short-lived EC2 instance.

# Next
This is more or less working, with some limitations:
 - Execution by bash script assumes one EC2 instance per job.
 - Execution by bash doesn't allow queueing or retrying of jobs.
 - Job and instance lifecycle are managed by client (ie must leave workstation or other instance running).
 - Bash scripts and environment variables take a lot of syntax to invoke.

A good next step would be to set up Kubernetes and a smart autoscaling policy.  Kubernetes config files could suck up a lot of the Bash syntax.  Kubernetes could do all the scheduling, management, retrying, etc.

Here are some links to pursue:
 - [Kubernetes on AWS](http://kubernetes.io/docs/getting-started-guides/aws/)
 - [EC2 Autoscaling based on Kubernetes Jobs](https://github.com/openai/kubernetes-ec2-autoscaler)
