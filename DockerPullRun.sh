#!/bin/bash

h="\n"
h+="`basename "$0"`: Copies deployment items to server and starts all services of a docker-compose Composition\n"
h+="\n"
h+="Command line parameters:\n"
h+="--login:      The ssh login to use\n"
h+="              Default can be set via dorie.default file\n"
h+="--profile:    The profile to use, specifies the subdirectory under deployment_items to copy\n"
h+="              Default can be set via dorie.default file\n"
h+="--deployitemsdir: The directory that is copied to the remote server\n"
h+="              Default: 'deployment_items'\n"
h+="--copy:       one or more directories to copy as well to the remote server\n"
h+="              Useful to get the directory containing the docker compose override file to the remote server\n"
h+="--targetdir:  target dir, where to copy the docker-compose files to, must be given as seen from server (~ will be locally resolved!)\n"
h+="              Default: /containers/<JOBNAME>/\n"
h+="--skippull:   Skips pull command during restart of container composition\n"
h+="              Usually necessary when used on a server without direct connection to the docker registry server\n"
h+="\n"
h+="Example:\n"
h+="./DockerBuild.sh --name awesomeproject --tag additionaltag1 --dockercomposefile build/docker-compose.override.yml --dockercomposeservicename webapp\n"
h+="\n"
h+="Later ./DockerPullRun.sh can be used to start:\n"
h+="./DockerPullRun.sh --login core@testserver --profile testserver --copy build\n"
h+="\n"
h+="Use a directory structure like this:\n"
h+="+ deployitemsdir\n"
h+="  + all (for items to copy to all servers)\n"
h+="  + server1 (items for server1, typically only a docker-compose.yml)\n"
h+="  + server2 (items for server1, typically only a docker-compose.yml)\n"
h+="+ additionaldir (--copy directory, typically containing a docker-compose.override.ym\n"
h+="                 to specify a specific image version, created by DockerBuild.sh)\n"

source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

# using from loaded config
# ssh_login=
# deployitemsdir=
# profile=

additionalcopydirs=()
skippull=false

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --login)
        ssh_login="$2"
        shift
        ;;
        --profile)
        profile="$2"
        shift
        ;;
        --deployitemsdir)
        deployitemsdir="$2"
        shift
        ;;
        --copy)
        additionalcopydirs+=($2)
        shift
        ;;
        --targetdir)
        targetdir="$2"
        shift
        ;;
        --skippull)
        skippull=true
        shift
        ;;
        --help)
        showHelp

        exit 0
        shift
        ;;
        *)
        echo "Unknown argument: $key"

        exit -1
        ;;
    esac
    shift
done

if [ -z $targetdir ]
then
    if [ ! -z $JOBNAME ]
    then
        targetdir="/containers/$JOBNAME/"
    fi
fi

if [ -z $targetdir ]
then
    pwd=${PWD##*/}
    echo "No target name given and could not be determined ny JOBNAME, creating from directory: $pwd"
    targetdir="containers/$pwd"
fi

if [ -z $ssh_login ]
then
    echo "No target server specified. Use --login to set server login"

    exit -1
fi

######################################################################
# deployment to server
######################################################################

echo "Deploying to $ssh_login with profile $profile"

echo "SSH Connection to server $ssh_login: Creating project folder $targetdir"
ssh -t -t "$ssh_login" "mkdir -p $targetdir"

if [ ! $? -eq 0 ]
then
    echo "Failed" >&2

    exit -1
fi

if [ -d "$deployitemsdir/all" ]; then
    echo "SSH Connection to server: Copying generic deployment items to server"
    scp -r $deployitemsdir/all/* "$ssh_login:$targetdir"
    if [ ! $? -eq 0 ]
    then
        echo "Failed" >&2

        exit -1
    fi
fi

if [ ! -z $profile ]; then
    if [ -d "$deployitemsdir/$profile" ]; then
        echo "SSH Connection to server: Copying profile deployment items to server: $profile"
        scp -r $deployitemsdir/$profile/* "$ssh_login:$targetdir"
        if [ ! $? -eq 0 ]
        then
            echo "Failed" >&2

            exit -1
        fi
    fi
fi

for additionalcopydir in ${additionalcopydirs[@]}; do
    echo "SSH Connection to server: Copying additional deployment items from $additionalcopydir to server"
    scp -r $additionalcopydir/* "$ssh_login:$targetdir"
    if [ ! $? -eq 0 ]
    then
        echo "Failed" >&2

        exit -1
    fi
done

sshCommand="cd $targetdir "
sshCommand+=' && PATH=$PATH:/opt/bin/:'
sshCommand+=" && echo \"stopping:\" && docker-compose stop"
sshCommand+=" && echo \"rm:\" && docker-compose rm -f"
if [ $skippull = true ]
then
    echo "Skipping pull command"
else
    sshCommand+=" && echo \"pull:\" && docker-compose pull"
fi

sshCommand+=" && echo \"build:\" && docker-compose build"
sshCommand+=" && echo \"up!:\" && docker-compose up -d --remove-orphans"

echo "SSH Connection to server: running command to delete and restarted docker container:"
echo "$sshCommand"
ssh -t -t "$ssh_login" "$sshCommand"

if [ $? -eq 0 ]
then
    echo "Succeeded" >&2
else
    echo "Failed" >&2

    exit -1
fi
