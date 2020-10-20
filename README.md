# ACE DevOps

This repo can be used as example to implement an automatic deployment of an AppConnect integration server where the Cloud Pak for Integration is installed.
The deployment is using Tekton pipeline.
It is possible to modify the deployment such that it might be possible to deploy without the CP4I. 

A trigger template is provided to trigger the pipeline using a git webhook.
The pipeline build an ace image using a **DockerFile**, publish the custom image in the openshift registry and then deploy the ace integration server into the cluster.

The deployment on the openshift cluster is done using AppConnect operator.

Two types of build is provided as example:
  - build from a ACE toolkit project (the default DockerFile). 
    In this approach, a bar file is generated from the ACE project and 
  - build from a ACE bar file

The pipeline is trigerred by a git event which triggers the build of ACE e

# Repo content
The repo contains the resources to install the Tekton pipeline and to build the custom ace image.
  - Assets: this folder contains the resources to install the pipeline
  - bars: this folder can be used to place the bar file to be installed on the integration server
  - source: this folder contains an example of application to be deployed : pingService

# Workflow
The workflow of the automatic deployment is the following:
  - A push is performed in the git repo
  - The webhook trigs the pipeline
  - The pipeline initiate the build
    - The git repo from branch main is cloned
    - The Dockerfile is used to build the ace image. The name of the image is composed from the imgcfg file
    - The image is pushed to the openshift registry
  - The pipeline initiate the deploy
    - An integration server CR is created based on the imgcfg input

# Installation
To use this pipeline, use the resources in the assets folder.

The resource are installed on the openshift cluster using
```
oc apply -f <resource.yaml>
```

## Prerequisites
- A kubernetes cluster with AppConnect Operator installed. The operator will create the required k8s objects based on the integrationserver CR defined by the deploy task. 
- Cloud Pak for Integration. The current deploy task creates an IntegrationServer CR that expects to have the Cloud Pak for Integration installed (license type, common services, operational dashboard). For kubernetes environment without the CP4I, the deploy task needs to be modified by changing the  IntegrationServer custom resource.

## Pipeline
The pipeline is using two pipelineresources and two tasks.
The pipelineresources are used to provide input to the tasks.

### pipelineresources
*Git resource*
Configuration provided by the file "acecicd-res-git.yaml".
The resource is used to define the git repository location.
> You need to update the git url $(params.url) according to your repository url.

The pipeline is defined by "acecicd-pipeline.yaml".

*Image resource*
Configuration provided by the file "acecicd-res-image.yaml".
The resource is used to define the image location.
It uses the standard registry url.

### tasks
*build*

Configuration provided by the file "acecicd-task-build.yaml".
The required properties can be configured at the pipeline level.

The task is building the ACE image with the **buildah** using a docker file.
By default **DockerFile** is used but it can be overriden using the DOKERFILE parameter.
The image used to run the container is __registry.redhat.io/rhel8/buildah__.
The build image url is __image-pipeline-reesource/namespace/imgcfg-name:imgcfg-version__
The image name and version used for the registry url are computed from the imgcfg file available in the git root directory (same level as the docker file).

The image is then pushed to the registry.

The tasks is generating two results from the imgcfg file: the image_tag and image_version.

*deploy*
Configuration provided by the file "acecicd-task-deploy.yaml".
The required properties can be configured at the pipeline level.

Default values that you might change according to your needs:
  - tracing is activated (operational dashboard integration ) with the operational dashboard installation namespace set to "tracing". It can be overwritten in the pipeline or by setting default value
  - license number is set to : L-APEH-BPUCJK

The namespace parameter can be configured at the pipeline level. 
The image name and tag is provided by the task build from the imgcfg file. 

Please note the following for the integration server custom resource that is created:
- The version used to run the integration serveer has to be fully qualified
- The image used to build the custom image is __ibmcom/ace-server:latest__ which is made for use with **AppConnect Operator**
- 

- The image is referenced with the field 
Integration Server custom resource created:
TODO
- image name fully qualified
- custom image
- license version


### pipeline
Configuration provided by the file "acecicd-pipeline.yaml".
Name: acecicd-pipeline

> The **params.namespace** can be modified according to your deployment
This is the namespace used to build the image url (registry/namespace/imageName:imageTag) and it is also used to define where the integration server will be deployed.
> The **Tasks.deploy-image.params.integrationServerName** can be modified if a specific integration server name has to be set. By default it is set to the image name.

Another pipeline is provided to deploy an existing image in the registry.
Configuration provided by the file "acecicd-pipeline-deploy.yaml".
> Note that you would had to provide the params of the pipeline in order to use it.

## Trigger
The pipeline can be triggered using a github webhook.
The trigger configuration is provided by the file **trigger-template.yaml**.

The configuration defines three k8s objects:
  - EventListener (acecicd-listener): this is a pod that is used by the pipeline to receive the github webhook and to launch the pipeline through the configuration provided in the trigger
  - TiggreTemplate (acecicd-pipeline-trigger): this defines what pipeline to run by creating a "pipelineRun" with a name starting with "acecicd-pipeline-run-" and referencing the pipeline "acecicd-pipeline".
  - Route (acecicd-webhook): this will create a route that can be used to configure the github webghook. The url generated by the route exposes the event listener.

> You need to set the right namespace in the triggertemplate.

# Execute and Test

- Install the pipeline
- Clone the git repository 
- Create the webhook in github using the generated url from the route.
  ```
  oc get route acecicd-webhook
  ```
- Copy your integration server project (directory with the content of your toolkit project) into the git source directory (or use the provided one "PingService")  
- Change the DockerFile according to your project directory that you have copied. Replace PingService by the name of your project directory
- Push your update to git
- Pipeline is triggered
- When the ace server has been started, it should be registered in the dashboard.
- Navigate to the REST API and performs a http get