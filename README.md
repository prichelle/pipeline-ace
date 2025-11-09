# ACE DevOps Pipeline

This repository provides an automated CI/CD solution for deploying IBM App Connect Enterprise (ACE) integration servers using Tekton pipelines on OpenShift/Kubernetes with Cloud Pak for Integration.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Workflow](#workflow)
- [Installation](#installation)
  - [Building ACE Minimal Image](#building-ace-minimal-image)
  - [Building ACE Maven Image](#building-ace-maven-image)
- [AppConnect Build Pipeline](#appconnect-build-pipeline)
- [AppConnect Deploy Pipeline](#appconnect-deploy-pipeline)
- [Automation with Webhooks](#automation-with-webhooks)
- [Running the Complete Pipeline](#running-the-complete-pipeline)
- [Troubleshooting](#troubleshooting)
- [Useful Commands](#useful-commands)

## Overview

This project demonstrates automated deployment of ACE integration servers using:
- **Tekton Pipelines** for CI/CD orchestration
- **AppConnect Operator** for deployment management
- **OpenShift Container Registry** for image storage
- **Git webhooks** for automated triggering

### Key Features
- Automated build and deployment of ACE integration servers
- Support for two build approaches:
  - Build from ACE toolkit project (generates BAR file from source)
  - Build from pre-existing ACE BAR file
- Minimal ACE image for efficient testing and building
- Unit testing integration with Maven
- Git webhook-based pipeline triggering
- OpenShift/CP4I integration with operational dashboard support

### Build Types
The pipeline supports two types of builds:
1. **Toolkit Project Build** (default): Generates a BAR file from ACE project sources
2. **BAR File Build**: Uses pre-existing BAR files from the `bars/` directory

### Architecture
The pipeline is triggered by Git events and executes the following:
1. Clone the Git repository
2. Build custom ACE image using Dockerfile
3. Push image to OpenShift registry
4. Deploy IntegrationServer CR using AppConnect Operator

To minimize image size for building and testing, a minimal ACE base image is built using a separate Tekton pipeline based on [ace-docker](https://github.com/tdolby-at-uk-ibm-com/ace-docker).

## Prerequisites

Before setting up the pipeline, ensure you have:

### Required Components
- **OpenShift/Kubernetes Cluster** (v4.8+)
- **AppConnect Operator** - Creates and manages IntegrationServer custom resources
- **Tekton Operator** (OpenShift Pipelines Operator)
- **Cloud Pak for Integration** (CP4I) - For license management, common services, and operational dashboard
  - For non-CP4I Kubernetes environments, modify the IntegrationServer CR in the deploy task
- **Git Repository** - For source code and webhook integration

### Required Images
The following images must be built before running the main pipeline:
1. **ACE Minimal Image** - Base image for efficient building and testing
2. **ACE Maven Image** - Built on top of minimal image, used for Java-based unit testing

### Access Requirements
- Cluster admin access or appropriate RBAC permissions
- OpenShift CLI (`oc`) installed and configured
- Access to OpenShift internal registry

## Repository Structure

```
pipeline-ace/
├── assets/           # Tekton pipeline resources and configurations
│   ├── tekton/      # Main pipeline, task, and resource definitions
│   ├── sample/      # Sample configurations and examples
│   └── docker/      # Additional Dockerfiles
├── bars/            # Directory for pre-built BAR files
├── source/          # ACE application source code (toolkit projects)
├── Dockerfile       # Main Dockerfile for building ACE server image
├── DockerFileMvn    # Dockerfile for Maven-based unit testing
├── DockerFile_aceminimal  # Dockerfile for minimal ACE image
└── imgcfg          # Configuration file for image name, tag, and app settings
```

### Directory Details
- **assets/tekton**: Contains all Tekton pipeline, task, and resource YAML files
- **bars/**: Place pre-built BAR files here for BAR-based deployments
- **source/**: Contains ACE application source code from toolkit workspace. Built by pipeline and packaged as BAR file for deployment

## Workflow

### Automated Deployment Process
1. **Git Push**: Developer pushes code changes to the Git repository
2. **Webhook Trigger**: Git webhook triggers the Tekton pipeline
3. **Build Phase**:
   - Clone Git repository (main branch)
   - Build ACE image using Dockerfile
   - Image name and tag are read from `imgcfg` file
   - Push image to OpenShift registry
4. **Deploy Phase**:
   - Create IntegrationServer custom resource (CR)
   - AppConnect Operator deploys the integration server
   - Server is registered with operational dashboard (if enabled)

## Installation

The Tekton pipeline is configured using Kubernetes resources in the `assets/tekton` folder.

### Basic Installation
Resources are installed on the OpenShift cluster using:

```shell
oc create -f <resource.yaml>
```

Or apply all resources at once:
```shell
oc apply -f assets/tekton/
```

### Grant Privileged Access

The pipeline requires privileged access to create directories in the Git workspace:

```shell
oc adm policy add-scc-to-user privileged -n <yourNamespace> -z pipeline
```

### Building ACE Minimal Image

The minimal image is built using the repository [ace-docker](https://github.com/tdolby-at-uk-ibm-com/ace-docker). The Dockerfile is located at `experimental/ace-minimal/Dockerfile.alpine` in that repository.

A copy of the Dockerfile is provided in this repo as `DockerFile_aceminimal`.

#### Steps to Build ACE Minimal Image:

1. Create the build task:
   ```shell
   oc create -f assets/tekton/acecicd-task-build-aceminimal.yaml
   ```

2. Create the pipeline:
   ```shell
   oc create -f assets/tekton/acecicd-pipeline-build-img-acemin.yaml
   ```

3. Create the image resource (defines OpenShift registry location):
   ```shell
   oc create -f assets/tekton/acecicd-res-image.yaml
   ```

4. Run the pipeline using the OpenShift UI or CLI

**Note**: The pipeline uses an external Git repository. The ACE developer image URL is configured in the task. Ensure version synchronization with the external repo, as scripts may include ACE version in their paths.

### Building ACE Maven Image

Unit test projects are Java-based and require Maven for compilation. The image is built using `DockerFileMvn` and depends on the ACE minimal image built in the previous step.

The Maven binaries are downloaded from Apache archive during the build.

**Future Enhancement**: Newer ACE versions support building unit test projects using `ibmint` command line (not yet implemented).

#### Steps to Build ACE Maven Image:

1. Create the build task:
   ```shell
   oc create -f assets/tekton/acecicd-task-buildacemvn.yaml
   ```

2. Create the pipeline:
   ```shell
   oc create -f assets/tekton/acecicd-pipeline-buildacemvn.yaml
   ```

3. Create the Git resource:
   ```shell
   oc create -f assets/tekton/acecicd-res-git.yaml
   ```

4. Create the image resource (if not already created):
   ```shell
   oc create -f assets/tekton/acecicd-res-image.yaml
   ```

5. Run the pipeline using the OpenShift UI

## AppConnect Build Pipeline

This pipeline creates a custom ACE image containing an IntegrationServer configured with resources from the `source` folder. The image can then be deployed directly to the cluster.

The pipeline builds App Connect source from the `source` folder in the repository.

### Pipeline Structure

```
(pipeline) acecicd-pack-test-build-acesrv [acecicd-pipeline-ptb-acesrv.yaml]
  |-> (task) pack-test-build-aceserver [acecicd-task-ptb-acesrv.yaml]
    |-> (step) prepare-bar
    |-> (step) run-unittest
    |-> (step) build-push-acesrv
```

The pipeline requires Git and image resources to retrieve source code and push the built image.

### Resources Configuration

#### Git Resource
Defined in `acecicd-res-git.yaml` - specifies the Git repository location.

**Important**: Clone this repository and add your own source code in the `source` directory. Use project folders from your toolkit workspace.

**Action Required**: Update the `$(params.url)` in the Git resource to point to your repository URL.

#### Image Resource
Defined in `acecicd-res-image.yaml` - specifies the registry location for pushing and pulling images.

Default value: `image-registry.openshift-image-registry.svc:5000` (standard OpenShift registry URL)

### Task Steps

#### 1. prepare-bar
Prepares the BAR file for unit testing and image creation. Uses the minimal ACE image.

**Process:**
- Clones the Git repository
- Uses `mqsipackagebar` to create the BAR file
- Applies property overrides using `mqsiapplybaroverride` (if property file exists)

**Property File**: Place a properties file named `<application_name>.properties` in the application folder (e.g., `HelloWorld/HelloWorld.properties`). An example is provided in the HelloWorld app.

#### 2. run-unittest
Runs unit tests. The unit test project name is defined in the `unittestprj` variable in the `imgcfg` file.

**Note**: Unit test libraries have dependencies defined in the POM file. Some libraries are from the App Connect installation, which includes the AppConnect version in the path. If you change versions, you may need to update the POM file.

#### 3. build-push-acesrv
Builds the custom ACE image using the default `Dockerfile`.

**Note**: Issues have been encountered with Kaniko. Refer to the [Troubleshooting](#troubleshooting) section.

### Installation and Execution

1. Create the resources:
   ```shell
   oc create -f assets/tekton/acecicd-res-git.yaml
   oc create -f assets/tekton/acecicd-res-image.yaml
   ```

2. Create the pipeline:
   ```shell
   oc create -f assets/tekton/acecicd-pipeline-ptb-acesrv.yaml
   ```

3. Create the task:
   ```shell
   oc apply -f assets/tekton/acecicd-task-ptb-acesrv.yaml
   ```

4. Run the pipeline from the OpenShift UI

## AppConnect Deploy Pipeline

This pipeline deploys the custom image built by the build pipeline.

Configuration is provided in `acecicd-task-deploy.yaml`. Required properties can be configured at the pipeline level.

### Default Configuration Values

You may need to change these according to your environment:
- **Tracing**: Enabled by default with operational dashboard namespace set to `tracing`
- **License**: `L-APEH-C49KZH` (CP4I non-production for ACE 12.0.1-12.0.2)
  - See [License annotations](https://www.ibm.com/docs/en/app-connect/containers_cd?topic=resources-licensing-reference-app-connect-operator) for details

The namespace, image name, and tag are configured from the `imgcfg` file.

### Important Notes
- The IntegrationServer version must be fully qualified
- The base image is `ibmcom/ace-server:latest`, designed for use with AppConnect Operator

### Installation and Execution

1. Create the deploy task:
   ```shell
   oc apply -f assets/tekton/acecicd-task-deploy.yaml
   ```

2. Create the deploy pipeline:
   ```shell
   oc apply -f assets/tekton/acecicd-pipeline-deploy.yaml
   ```

3. Create the image resource (if not already created):
   ```shell
   oc create -f assets/tekton/acecicd-res-image.yaml
   ```

4. Start the pipeline using the OpenShift UI

### Validation

Verify the IntegrationServer deployment:

```shell
oc get integrationserver
```

Expected output:
```
NAME                  RESOLVEDVERSION   REPLICAS   AVAILABLEREPLICAS   CUSTOMIMAGES   STATUS   AGE
ace-helloword-10      12.0.2.0-r1       1          1                   true           Ready    10m
```

## Automation with Webhooks

The pipeline can be triggered automatically using a GitHub webhook. The trigger configuration is provided in `trigger-template.yaml`.

### Components

The following Kubernetes objects automate the deployment:

1. **EventListener** (`acecicd-listener`): Pod that receives GitHub webhooks and launches the pipeline
2. **TriggerTemplate** (`acecicd-pipeline-trigger`): Defines which pipeline to run by creating a PipelineRun with name prefix `acecicd-pipeline-run-`
3. **Route** (`acecicd-webhook`): Exposes the EventListener via a public URL for GitHub webhook configuration

### Installation

1. Apply the trigger resources:
   ```shell
   oc apply -f assets/tekton/trigger-template.yaml
   ```

   **Important**: Update the namespace in the TriggerTemplate to match your environment.

2. Get the webhook URL:
   ```shell
   oc get route acecicd-webhook
   ```

   The route exposes an HTTP URL that can be used to configure the GitHub webhook.

3. Install the process-git pipeline:
   ```shell
   oc apply -f assets/tekton/acecicd-pipeline-process-git.yaml
   ```

4. Install the get-config task:
   ```shell
   oc apply -f assets/tekton/acecicd-task-get-config.yaml
   ```

The pipeline clones the Git repository and uses the `get-config` task to set environment variables from the `imgcfg` file.

## Running the Complete Pipeline

### Setup Steps

1. **Clone the repository**:
   ```shell
   git clone <your-repo-url>
   cd pipeline-ace
   ```

2. **Create the GitHub webhook**:
   - Get the webhook URL: `oc get route acecicd-webhook`
   - Configure the webhook in your GitHub repository settings

3. **Add your integration server project**:
   - Copy your integration server project directory (from toolkit workspace) to the `source/` folder
   - Or use the provided example (`PingService`)

4. **Update the Dockerfile**:
   - Replace `PingService` with your project directory name

5. **Configure the imgcfg file**:
   - Set the desired image name and tag
   - Set the ACE application name
   - Set the unit test project name (if applicable)

6. **Push changes to Git**:
   ```shell
   git add .
   git commit -m "Configure pipeline for my project"
   git push
   ```

7. **Pipeline executes automatically**:
   - The webhook triggers the pipeline
   - Build and deploy processes run automatically
   - The ACE server registers with the dashboard (if enabled)

8. **Test the deployment**:
   - Navigate to the REST API endpoint
   - Perform an HTTP GET request

## Sample Alternative: Buildah

An alternative example using Buildah for image building is provided in `assets/sample/tekton/`.

### Key Differences
- Uses `registry.redhat.io/rhel8/buildah` as the builder image
- Default Dockerfile is `DockerFile` (can be overridden with DOCKERFILE parameter)
- Image URL format: `<image-pipeline-resource>/<namespace>/<imgcfg-name>:<imgcfg-version>`
- Image name and version are computed from the `imgcfg` file in the repository root

### Task Results
The task generates two results from the `imgcfg` file:
- `image_tag`: Tag for the image
- `image_name`: Name of the image

These results are used by subsequent tasks to compose the full image URL.

## Troubleshooting

### Build Image Issues with Kaniko

#### SSL Certificate Problems

Tekton changed how certificates are injected. The certificate volume mount path changed from `/etc/config-registry-cert/` to `/etc/ssl/certs`. Since Tekton mounts a read-only volume, this can cause build failures.

**Error Message:**
```
Unpacking rootfs as cmd COPY bars /home/aceuser/initial-config/bars requires it.
error building image: error building stage: failed to get filesystem from image:
error removing ./etc/ssl/certs to make way for new symlink:
unlinkat /etc/ssl/certs/service-ca.crt: device or resource busy
```

**Solution:**

Set the `SSL_CERT_DIR` environment variable in your build step:

```yaml
- name: build-push-acesrv
  image: gcr.io/kaniko-project/executor:v0.16.0
  env:
    - name: "DOCKER_CONFIG"
      value: "/tekton/home/.docker/"
    - name: "SSL_CERT_DIR"
      value: "/tmp/other-ssl-dir"
```

**References:**
- [Kaniko Issue #1692](https://github.com/GoogleContainerTools/kaniko/issues/1692)
- [Tekton Bugzilla](https://bugzilla.redhat.com/show_bug.cgi?id=1973677)

### Common Issues

#### Version Mismatch
If you encounter errors related to missing files or incorrect paths, check that ACE versions are consistent across:
- Base images
- POM file dependencies
- Pipeline task configurations

#### Permission Denied
Ensure the pipeline service account has privileged access:
```shell
oc adm policy add-scc-to-user privileged -n <yourNamespace> -z pipeline
```

#### Image Pull Errors
Verify that:
- The image resource URL is correct
- The OpenShift registry is accessible
- Service accounts have pull/push permissions

## Useful Commands

### Clean Up Pipeline Runs
```shell
oc delete pipelinerun --all -n ace
```

### View Pipeline Logs
```shell
oc logs -f <pod-name> -n ace
```

### Check Integration Server Status
```shell
oc get integrationserver -n ace
```

### View Pipeline Resources
```shell
oc get pipeline,pipelinerun,task,taskrun -n ace
```

### Debug a Failed Pod
```shell
oc describe pod <pod-name> -n ace
oc logs <pod-name> -n ace
```

### Get Webhook URL
```shell
oc get route acecicd-webhook -n ace -o jsonpath='{.spec.host}'
```

## Configuration File Reference

### imgcfg File
The `imgcfg` file contains key configuration variables:

```bash
export imgtag="1.1"              # Image tag version
export imgname="ace-helloworld"  # Image name
export aceappname="HelloWorld"   # ACE application name
export unittestprj="HelloWorld_Test"  # Unit test project name
```

Update these values according to your project requirements.

## License

Refer to the IBM App Connect Enterprise licensing documentation for proper license configuration in your environment.

## Contributing

Contributions are welcome! Please ensure:
- YAML files are properly formatted
- Documentation is updated for new features
- Testing is performed in a non-production environment first

## Support

For issues and questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review IBM App Connect Enterprise documentation
- Consult Tekton Pipelines documentation
