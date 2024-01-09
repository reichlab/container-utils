# container-utils

This repo contains utility scripts that help writing containerized apps. It also contains documentation on setting up the `/data` volume needed by most lab containers, tips for building images and specifying user accounts to run scripts under, as well as the lab's [Amazon Elastic Container Service](https://aws.amazon.com/ecs/) (ECS) setup.

# Scripts in this repo

- [load-env-vars.sh](scripts/load-env-vars.sh): Processes the below required environment variables to set up git and Slack operations. Load this file (via [source](https://linuxize.com/post/bash-source-command/)) and then load [slack.sh](scripts/slack.sh).
- [slack.sh](scripts/slack.sh): Defines two Slack communication functions:
    - `slack_message()`: Post a message to the passed Slack channel.
    - `slack_upload()`: Upload a file to the passed Slack channel.

# Environment variables required by the scripts 

[load-env-vars.sh](scripts/load-env-vars.sh) requires the following environment variables.

> Note It's easiest and safest to save these in a `*.env` file and then pass that file to `docker run` as done below in "Steps to run the image locally".

- `SLACK_API_TOKEN`, `CHANNEL_ID`: [API token](https://api.slack.com/authentication/token-types#bot) for the lab's slack API and the Slack channel id to send messages to, respectively. Saved into `~/.env`.
- `GH_TOKEN`: [GitHub personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) that the [GitHub CLI](https://cli.github.com/) will use. Saved into `~/.env`.
- `GIT_USER_NAME`, `GIT_USER_EMAIL`: Global `user.name` and `user.email` values to save into the `~/.gitconfig` [Configuration variables file](https://git-scm.com/docs/git-config#_configuration_file) via `git config --global ...`.
- `GIT_CREDENTIALS`: GitHub personal access token as used by [git-credential-store](https://git-scm.com/docs/git-credential-store). Saved into `~/.git-credentials`.

## Supporting a `DRY_RUN` environment variable

Most lab scripts support a `DRY_RUN` environment variable that's used during development. Typically, the scripts check for that variable being set and, if so, exit before performing any permanent changes such as git operations. This allows running a script locally through the call to the actual model being containerized so that output(s) can be examined. 

# The `/data` dir

Most lab containers expect a volume (either a [local Docker one](https://docs.docker.com/storage/volumes/) or an [AWS EFS](https://aws.amazon.com/efs/) file system) to be mounted at `/data` and which contains any required GitHub repos. How that volume is populated (i.e., running `git clone` calls) depends on whether you're running locally or on ECS:

## populate a local Docker volume

Launch a temporary container that mounts the Docker volume at `/data`. E.g.,

```bash
# create the empty volume
docker volume create data_volume

# connect to the volume from the command line via a temp container
docker run --rm -it --name temp_container --mount type=volume,src=data_volume,target=/data ubuntu /bin/bash

# install git if necessary
apt update ; apt install -y git

# install required repos
cd /data
git clone ...
```

## populate an EFS volume

Launch a temporary [AWS EC2](https://aws.amazon.com/ec2/) instance that mounts the EFS file system at `/data`. See https://github.com/reichlab/container-utils/blob/main/docs/ecs.md for details.


## cloning the covid19-forecast-hub fork

Most lab scripts require working with [this fork](https://github.com/reichlabmachine/covid19-forecast-hub) of the https://github.com/reichlab/covid19-forecast-hub repo. To clone the covid19-forecast-hub fork and do a one-time setup of sync:

```bash
# clone the covid19-forecast-hub fork and do a one-time setup of sync
cd /data
git clone https://github.com/reichlabmachine/covid19-forecast-hub.git
cd /data/covid19-forecast-hub
git remote add upstream https://github.com/reichlab/covid19-forecast-hub.git
git fetch upstream
git pull upstream master
```

# Amazon ECS Documentation

- [ecs.md](docs/ecs.md): Documents the lab's [ECS](https://aws.amazon.com/ecs/) setup.
