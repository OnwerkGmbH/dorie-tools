# Dorie Tools

Provides a set of bash shell scripts to help include Docker in Continuous Integration and Deployment

Usual workflow:

1. Use `DockerBuild.sh` to create a docker image during a Jenkins Build Job, tag it accordingly and push it to a docker registry
2. For automatic deployment of the newly created docker image use `DockerPullRun.sh` during a Jenkins Build Job to servers with access to the docker registry  
 This script copies various deployment items to the server (items for all servers and items for the specific server).  
 After the copying the newly created docker image will be pulled from Docker Registry and started by using `docker compose`
3. For automatic deployment to servers without access to the docker registry the newly created image must be archived and transferred to the server.  
 Use `DockerPackImage.sh` to archive the docker image to an archive file, then use `DockerTransferPacked.sh` to transfer the archive to the server, extract it there and reload it into docker on the server. 
4. If no password-less SSH login can be used, transfer the archive file manually to the server and use 'DockerLoadFromArchive.sh' to extract it and load it into docker.  
 In that case all deployment-items must be manually copied to the server
 
## DockerBuild.sh

Builds a docker image, tags it automatically based on (Jenkins) job information and pushes it to the docker registry

Command line parameters:
```
--prefix:  The prefix to use in the registry url, i.e. dockerregistry:5000/<prefix>/nameofimage
           Default can be set via dorie.default file
--name:    The name to use in the registry url, i.e. dockerregistry:5000/<prefix>/<name>
           Default: Env variable JOBNAME or directory
--dockerfile: The dockerfile to build
           Default: .
--dockercomposefile: create a docker compose override file, use docker-compose.override.yml for automatic use by docker-compose, otherwise use docker-compose with -f.
           --dockercomposeservicename must also be specified
--dockercomposeservicename: the service name to extend. Must be given when dockercomposefile is used
```

Example:
```
DockerBuild.sh --name dcitoolstest   \
               --tag greatestversion \
               --dockercomposefile build/docker-compose.override.yml \
               --dockercomposeservicename webapp
```
later `DockerPullRun.sh` can be used to start:
```
DockerPullRun.sh --login core@testserver \
                 --profile testserver    \
                 --copy build
```

If `--dockercomposefile` is specified a docker-compose.yml-file with the given file name is generated that looks like
```
#
# Created by Dorie Tools, DockerBuild.sh, Dorie Tools
#
# DORIETOOLS_CREATED_TAG:thecreatedtag
# DORIETOOLS_CREATED_IMAGE:dockerregistry:5000/customername/awesomeproject:thecreatedtag
#

version: '2'
services:
    webapp:
        image: dockerregistry:5000/customername/awesomeproject:thecreatedtag
```

## DockerPullRun.sh

Copies deployment items to server and starts all services of a docker-compose Composition

Command line parameters:
```
--login:      The ssh login to use
              Default can be set via dorie.default file
--profile:    The profile to use, specifies the subdirectory under deployment_items to copy
              Default can be set via dorie.default file
--deployitemsdir: The directory that is copied to the remote server
              Default: 'deployment_items', can be customized via dorie.default file
--copy:       one or more directories to copy as well to the remote server
              Useful to get the directory containing the docker compose override file to the remote server
--targetdir:  target dir, where to copy the docker-compose files to, must be given as seen from server (~ will be locally resolved!)
              Default: /containers/<JOBNAME>/
--skippull:   Skips pull command during restart of container composition
              Usually necessary when used on a server without direct connection to the docker registry server
```

Example
```
DockerBuild.sh --name awesomeproject \
               --tag additionaltag1  \
               --dockercomposefile build/docker-compose.override.yml \ 
               --dockercomposeservicename webapp
```

later DockerPullRun.sh can be used to start:

```
DockerPullRun.sh --login core@testserver \
                 --profile testserver    \
                 --copy build
```

Use a directory structure like this:
```
+ deployitemsdir
  + all (for items to copy to all servers)
  + server1 (items for server1, typically only a docker-compose.yml)
  + server2 (items for server1, typically only a docker-compose.yml)
+ additionaldir (--copy directory, typically containing a docker-compose.override.ym
                 to specify a specific image version, created by DockerBuild.sh)
```

## DockerPackImage.sh

Pulls a docker image from docker registry and saves the image into a zipped file

Command line parameters:
```
--image:   The image to pull and pack, i.e. dockerregistry:5000/customername/awesomeproject:20160917_build48_develop
--zip:     The archive file name to create
```

Example:
```
DockerPackImage.sh --image dockerregistry:5000/customername/awesomeproject:20160917_build48_develop \
                   --zip awesomeproject.tar.gz
```
Tip: Use `DockerGetInfo.sh` to retrieve the just created image and tag to generate a meaningful file name:
```
DockerPackImage.sh \
    --image `DockerGetInfo.sh --dockercomposefile build/docker-compose.override.yml --image` \
    --zip export_`DockerGetInfo.sh --dockercomposefile build/docker-compose.override.yml --tag`.tar.gz
```

## DockerTransferPacked.sh

Transfers an archived docker image (created by DockerPackImage.sh) to a server, extracts it and loads it back into docker

Command line parameters:
```
--zip:     The archived docker image fiole to transfer
--login:   The ssh login to use
           Default can be set via dorie.default file
--targetdir: The target directory on the server, must be given as seen from server (~ will be locally resolved!)
           Default: /containers/<JOBNAME>/
```

Example:
```
DockerTransferPacked.sh --zip awesomeproject.targ.gz \
                        --targetdir /srv/containers/awesomeproject/
```

## DockerLoadFromArchive.sh

Extracts an archived docker image (created by DockerPackImage.sh) and loads it back into docker

Command line parameters:
```
--zip:     The archive file name to load the docker image from
```

Sample:
```
DockerLoadFromArchive.sh --zip awesomeproject.tar.gz
```

## DockerGetInfo.sh

Extracts the docker image URL or the created tag from a docker-compose.override.yml file created by DockerBuild.sh

Command line parameters:
```
--dockercomposefile: The docker-compose.override.yml file to extract the image URL from
--image:             Specifies that the image url should be retrieved, this is the default
--tag:               Specifies that the created tag should be retrieved
```

Example:
```
DockerGetImageUrl.sh --dockercomposefile build/docker-compose.override.yml
```

## Default values

Default values can be changed by using a `dorie.default` file with content like this:
```
prefix=""                           # your default prefix for storing images in the registry, like "myprefix"
registry=""                         # your default registry server like "dockerregistry:5000"
ssh_login=""                        # your login name for ssh-login into testserver like "core@testserver"
profile=""                          # default deployment profile (directory under $deployitemsdir, like "testserver"
deployitemsdir="deployment_items"   # default deployment items directory
```
These locations are searched for a defaults-file:
- `~/dorie.default`
- `./dorie.default`