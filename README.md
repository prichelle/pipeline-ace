# pipeline-ace
devops with ACE


# Pipeline architecture

A **pipeline** contains **tasks** that has to be executed.
Tasks can have input and output parameters.
The **pipelinerun** object is used to run the pipeline and to provide reference for the input and output parameters. 
These input and output parameters corresponds to **pipelineresources**.

Input and output can be pass to these tasks  by the task can be provided by is excecuted by "pipelinerun".
The pipelinerun defines:
  - the pipeline reference to run
  - the pipeline resources. These resources will be used as input or output by tasks. Resource type can be of git, pull request, image, ...
    Additional information can be found at the [github tekton](https://github.com/tektoncd/pipeline/blob/master/docs/resources.md#image-resource)
    In our case we are going to use git and image:
      - git: The git resource represents a git repository, that contains the source code to be built by the pipeline. 
      - image: An image resource represents an image that lives in a remote repository.

The devops pipeline provided here is very simple, it builds an ace image that contains a bar file that has been copied from the git repo and deploy it.
The tasks would be:
  - build the ace image with the bar file 
  - deploy the ace image
The resources are:
  - **git**: input resource to the build task is the cloned git repo
  - **image**: resource representing the image that has been build. It's the output of the build task and the input of the deploy task

# Tekton objects 
## Tasks
A task has 
- input/output parameters (spec.params)
- recourses that are passed by the pipeline ?
- steps: operation to be executed in order. The steps defines the following:
  - command to be executed
  - image: this is the image used to execute the command
  - securitycontext: privileged is required when pushing images to the registry
  - workingDir: location where the command will be executed
  - resources can be used to set limits for memory and cpu
### ace-build-task

This task is used to build the ace image and push it to the registry.
It uses **buildah** (https://buildah.io/).
Buildah allows to build oci image from DockerFile using the buildah command **bud** or (build-using-dockerfile). 
OCI images built using the Buildah command line tool (CLI) and the underlying OCI based technologies (e.g. containers/image and containers/storage) are portable and can therefore run in a Docker environment.
(https://github.com/containers/buildah/blob/master/docs/tutorials/01-intro.md#using-dockerfiles-with-buildah)

```
buildah bud -f myDockerFile -t imageNameToCreate .
buildah bud -t imageNameToCreate .
```
Detailed options can be found here [git buildah-bud](https://github.com/containers/buildah/blob/master/docs/buildah-bud.md)


The first step uses **buildah bud** to build an image from a Docker file.
The image used to run "buildah" is defined by the param builder_image.
The image build will be set to the parameter referenced by the resource image under url.
The registry used to push the image is provided by the parameter 


The images are stored in containers/storage and needs to be copy where the Docker daemon stores its images.

**buildah push** is used to push the images.
Detailed information can be found at the [github buildah-push](https://github.com/containers/buildah/blob/master/docs/buildah-push.md)

```
buildah push [options] myImageInBuildah [destination]
```
The Image "DESTINATION" uses a "transport":"details" format. Multiple transports are supported.
Here we are using "docker://docker-reference" since openshift is a registry implementing the "Docker Registry HTTP API V2".

Please note that the docker file use as image the one available in github.
**Attention** This tutorial is using the ACE operator to publish the integration server into the cluster. Not all images are compatible with the operator. We are using [ibmcom/ace-server](https://hub.docker.com/r/ibmcom/ace-server)

### deploy

This task publish an ace image into the cluster by using the IntegrationServer CR.

Instead of referencing the barUrl, this cr definition is using (spec.pod.containers.runtime.image) to set the image to use.
Please refer to the [ACE documentation](https://www.ibm.com/support/knowledgecenter/SSTTDS_11.0.0/com.ibm.ace.icp.doc/certc_install_integrationserveroperandreference.html) for additional information.

TODO: 
- release tag in template
      params:
      - name: imageTag
        value: $(uid)


