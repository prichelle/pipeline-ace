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

In order to minimise the size of the ACE image for building and testing the ACE flows, a minimal ace image is built and use use in the Tekton pipeline.
The building of this image is also done using a tekton pipeline and the git repo "https://github.com/tdolby-at-uk-ibm-com/ace-docker".

# Repo content
The repo contains the resources to install the Tekton pipeline and to build the custom ace image.
  - Assets: this folder contains the resources to setup the pipeline
  - bars: this folder can be used to place the bar file to be installed on the integration server. One tekton task is using this folder of the git repo to deploy bars. 
  - source: this folder contains an example of an ACE application integration source (from the toolkit folder). The source is build by a tekton pipeline and packaged as a bar file. The bar is ultimately deployed on a IntegrationServer.

# Workflow
The automatic deployment workflow is:
  - A git push is performed into the git repo
  - A webhook triggers the Tekton pipeline
  - The pipeline initiates the build
    - The git repo from branch main is cloned
    - The Dockerfile is used to build the ace image. The name of the image is composed from the imgcfg file
    - The image is pushed to the openshift registry
  - The pipeline initiates the deploy
    - An integration server CR is created based on the imgcfg input

# Installation

The Tekton pipeline is setup using the k8s resources available in the git assets folder.

The resources are installed on the openshift cluster using  

```shell
oc create -f <resource.yaml>
```

## Prerequisites
- A kubernetes cluster with AppConnect Operator installed. The operator will create the required k8s objects based on the integrationserver CR defined by the deploy task. 
- The Tekton operator (OpenShift pipeline operator)
- Cloud Pak for Integration. The current deploy task creates an IntegrationServer CR that expects to have the Cloud Pak for Integration installed (license type, common services, operational dashboard). For kubernetes environment without the CP4I, the deploy task needs to be modified by changing the  IntegrationServer custom resource.
- The ACE minimal image needs to be build before starting the main tekton pipeline. This minimal image is used to build the maven image that is in turn used to build the unit test that is part of the deployment.

### Building ace minimal
The image is build using the git repository "https://github.com/tdolby-at-uk-ibm-com/ace-docker".  
The docker file used to build the image is located at this repo under "experimental/ace-minimal/Dockerfile.alpine".

A copy of the Dockerfile is provided in this repo (file DockerFile_aceminimal).

To run this pipeline:
- Create the task "build_aceminimal": ``` oc create -f acecicd-task-build-aceminimal.yaml ```
- Create the pipeline "acecicd-build-acemin-img": ``` oc create -f acecicd-pipeline-build-img-acemin.yaml ```
- Create the image resource "image" which is used to define the openshift registry location where the image will be pushed: ``` oc create -f acecicd-res-image.yaml ```
- Run the pipeline using the UI 

The current implementation of the pipeline is using the external git repo.  
The pipeline task is defining an ACE developer image url to build the custom minimal ace image. It might be possible that the version is not synchronized with the one defined in the git repo. For instance some scripts has the ACE version in their path and might lead to error.  
The option to provide the image url is provided as example to enhanced the deployment.  

### Building the ACE maven 

The unit test project is based on java and need to be compiled in order to be run.  
The project is build using Maven and is downloading the binaries from apache archive. Please check the Docker file.

The last version of ACE provides the ability to build the unit test project using ibmint command line (not yet tested and will be an enhancement in this git project).  
The image is built using the Docker file DockerFileMvn provided in this repo and the ace minimal image that has been built in the previous section.  


To run this pipeline:
- Create the task "build-acemvn-img": ``` oc create -f acecicd-task-buildacemvn.yaml ```
- Create the pipeline "acecicd-build-acemvn": ``` oc create -f acecicd-pipeline-buildacemvn.yaml ```
- Create the resource git: ``` oc create -f acecicd-res-git.yaml ```
- Create the image resource "image", if not already done, which is used to define the openshift registry location where the image will be pushed: ``` oc create -f acecicd-res-image.yaml ```
- Run the pipeline using the UI 

# AppConnect build image pipeline

This pipeline creates a new custom ACE image that will contains an ACE Integration Server configured with the resources available in the git "source" folder. This image can then be deployed directly in the cluster.  

This part explains how to run the AppConnect pipeline it self.  
The pipeline is building the App Connect source from the source folder provided in the repository.  

The pipeline is provided in the yaml file "acecicd-pipeline-ptb-acesrv". The structure of the pipeline is as follow:

```
(pipeline) acecicd-pack-test-build-acesrv [acecicd-pipeline-ptb-acesrv.yaml]
  |-> (task) pack-test-build-aceserver [acecicd-task-ptb-acesrv.yaml]
    |-> (step) prepare-bar
    |-> (step) run-unittest
    |-> (step) build-push-acesrv

```

The pipeline requires the git and image resources. The git to get the source and the image to be able to push the image built.  

## Resources

**GIT**  
The resource is defined in the file "acecicd-res-git.yaml" and is used to define the git repository location.

You should clone this repository and add your own source code in the source directory. Those are just the project folder available under the toolkit workspace.  

```diff
+ You need to update the git url $(params.url) according to your repository url.
```

**IMAGE**

The image resource is defined in the file "acecicd-res-image.yaml".
The resource is used to define the registry location where the image that will be build will be pushed and pulled.  
The default value is "image-registry.openshift-image-registry.svc:5000" which is the standard registry url for an openshift cluster.  

## task
This task 
The steps defined in the task "pack-test-build-aceserver" are described here after.  

### prepare-bar

This step is preparing the bar file that will be used to perform the unit test and create the ace image.  The image used to run this step is the minimal ace image.  

The step just clone the git repo and uses the mqsipackage to create the bar file and the command mqsiapplybaroverride is called if a property file is provided.  

The property file should be placed under the application folder (here for the example is "HelloWorld" and should be called "<application_name>.properties").
An example is provided here under the HelloWorld app.  

### run-unittest  
This step is running the unit test. The name of the unit test is provided by the unittestprj variable defined in the imgcfg file.

The UnitTest has librairies dependencies defined in the POM file. Some of these library are provided by the app connect library. 
The AppConnect installation path includes the appconnect version, which means that if you change the version you might need to adapt the POM file.
### build-push-acesrv
This step will build the ACE custom image. 
it uses as default the docker file "DockerFile".   

I encountered issues with the image build with Kaniko. Please refers to the topic Troubleshooting at the end.
## Install the pipeline & run

- create the resources with the res-git and res-img yaml file
- create the pipeline "acecicd-pipeline-ptb-acesrv.yaml"
- create the task ``` oc apply -f acecicd-task-ptb-acesrv.yaml ```

The pipeline requires priviledge access to create the directory in the git workspace.

The following command has been issued to add the priviledge access to the pipeline service account:  

```shell

oc adm policy add-scc-to-user privileged -n <yourNameSpace> -z pipeline
```


# AppConnect deploy image pipeline

This pipeline is used to deploy the custom image that has been built by the build image pipeline.  


Configuration provided by the file "acecicd-task-deploy.yaml".
The required properties can be configured at the pipeline level.

Default values that you might change according to your needs:
  - tracing is activated (operational dashboard integration ) with the operational dashboard installation namespace set to "tracing". It can be overwritten in the pipeline or by setting default value
  - license number is set to : L-APEH-C49KZH (you might need to adapt this license based on your deployment). This corresponds to a CP4I non production for ACE 12.0.1-12.0.2.

  Licensing information can be found here: [License annotations](https://www.ibm.com/docs/en/app-connect/containers_cd?topic=resources-licensing-reference-app-connect-operator)

The namespace parameter can be configured at the pipeline level. 
The image name and tag is provided by the task build from the imgcfg file. 

Please note the following for the integration server custom resource that is created:
- The version used to run the integration serveer has to be fully qualified
- The image used to build the custom image is __ibmcom/ace-server:latest__ which is made for use with **AppConnect Operator**

## Install & start

- Create the task "deplay-aceimg": ```oc apply -f acecicd-task-deploy.yaml```
- Create the pipeline "acecicd-deploy": ```oc apply -f acecicd-pipeline-deploy.yaml```
- Create the resource image if not already done
- Start the pipeline using the UI.

You can validate that the integration server has been correctly deployed using:

```
oc get integrationserver                                                                                                               1.584s  (main|✚?) 10:15
NAME                           RESOLVEDVERSION   REPLICAS   AVAILABLEREPLICAS   CUSTOMIMAGES   STATUS   AGE
ace-helloword-10               12.0.2.0-r1       1          1                   true           Ready    10m
```

# Automating the deployment using trigger
The pipeline can be triggered using a github webhook.
The trigger configuration is provided by the file **trigger-template.yaml**.


The following k8s objects are used to automate the deployment:
  - **EventListener** (acecicd-listener): this is a pod that is used by the pipeline to receive the github webhook and to launch the pipeline through the configuration provided in the trigger. 
  - **TiggreTemplate** (acecicd-pipeline-trigger): this defines what pipeline to run by creating a "pipelineRun" with a name starting with "acecicd-pipeline-run-" and referencing the pipeline "acecicd-pipeline".
  - **Route** (acecicd-webhook): this will create a route that can be used to configure the github webghook. The url generated by the route exposes the event listener.
## Install

1. The required objects for the triggering are provided in trigger-template.yaml file.

```
oc apply -f trigger-template.yaml
```

```diff
+ You need to set the right namespace in the triggertemplate.
```

The route provides an URL that can be called to trigger the pipeline. This URL can be used to configure the git repo webhook.

The cp4i hostname exposed by the route can be retrieved using 
``` 
oc get route | grep webhook
```
The route is exposed using http.

2. The pipeline to process the git request is provided with process-git.

The pipeline clone the git repo and use the task **get-config** to set environment variable using the **imgcfg** file.
- Install the process-git pipeline:
  ```
   oc apply -f acecicd-pipeline-process-git.yaml
  ```
- Install the task get-config: 
  ```
  oc apply -f acecicd-task-get-config.yaml
  ```
# Run the whole pipeline

- Clone the git repository 
- Create the webhook in github using the generated url from the route.
  ```
  oc get route acecicd-webhook
  ```
- Copy your integration server project (directory with the content of your toolkit project) into the git source directory (or use the provided one "PingService")  
- Change the DockerFile according to your project directory that you have copied. Replace PingService by the name of your project directory
- Adapt the **imgcfg** file to reflect the image name and tag that you would like to use.
- Push your update to git
- Pipeline is triggered
- When the ace server has been started, it should be registered in the dashboard.
- Navigate to the REST API and performs a http get


# Sample


Another example is provided where buildah is used to build the image. The example is provided under "/assets/sample/tekton".  

The image used to run the container is __registry.redhat.io/rhel8/buildah__.

By default **DockerFile** is used but it can be override using the DOKERFILE parameter.

The build image url used to push the generated image is __image-pipeline-reesource/namespace/imgcfg-name:imgcfg-version__ and it is pushed to the registry.
 - The image name and version used for the registry url are computed from the **imgcfg** file available in the git root directory (same level as the docker file).

The tasks is generating two *results* from the **imgcfg** file. These results are used by the next tag to recompose the image url.
  - image_tag 
  - image_version
# Troubleshooting

## Build images
I had different issues with Kaniko.   

### SSL issues

 Tekton changed the way certificates are injected and the cert volume is mounted. 
 It used to have /etc/config-registry-cert/ as a mountPath, where the updated version uses /etc/ssl/certs. 
 Since Tekton mounts a read-only volume, it fails to build the image with the following error:

 ```
 Unpacking rootfs as cmd COPY bars /home/aceuser/initial-config/bars requires it. 
error building image: error building stage: failed to get filesystem from image: error removing ./etc/ssl/certs to make way for new symlink: unlinkat /etc/ssl/certs/service-ca.crt: device or resource busy
 ```  

To solve the isssue, I followed the recommendation at [Kaniko issues](https://github.com/GoogleContainerTools/kaniko/issues/1692) and created the following step withe the **SSL_CERT_DIR** env variable:

```yaml
   - name: build-push-acesrv
      image: gcr.io/kaniko-project/executor:v0.16.0
      # specifying DOCKER_CONFIG is required to allow kaniko to detect docker credential
      env:
        - name: "DOCKER_CONFIG"
          value: "/tekton/home/.docker/"
        - name: "SSL_CERT_DIR"
          value: "/tmp/other-ssl-dir"
```

Other reference:
[Tekton bugzilla](https://bugzilla.redhat.com/show_bug.cgi?id=1973677)

# Useful command line

``` oc delete pipelinerun --all -n ace ```
