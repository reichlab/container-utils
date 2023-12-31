# container-utils

This repo contains utility scripts that help writing containerized apps. It also contains documentation on the lab's [Amazon Elastic Container Service](https://aws.amazon.com/ecs/) (ECS) setup.

# Scripts

- [load-env-vars.sh](scripts/load-env-vars.sh): Processes the below required environment variables to set up git and Slack operations. Load this file (via [source](https://linuxize.com/post/bash-source-command/)) and then load [slack.sh](scripts/slack.sh).
- [slack.sh](scripts/slack.sh): Defines two Slack communication functions:
    - `slack_message()`: Post a message to the passed Slack channel.
    - `slack_upload()`: Upload a file to the passed Slack channel.

# Environment variables

[load-env-vars.sh](scripts/load-env-vars.sh) requires the following environment variables.

> Note It's easiest and safest to save these in a `*.env` file and then pass that file to `docker run` as done below in "Steps to run the image locally".

- `SLACK_API_TOKEN`, `CHANNEL_ID`: [API token](https://api.slack.com/authentication/token-types#bot) for the lab's slack API and the Slack channel id to send messages to, respectively. Saved into `~/.env`.
- `GH_TOKEN`: [GitHub personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) that the [GitHub CLI](https://cli.github.com/) will use. Saved into `~/.env`.
- `GIT_USER_NAME`, `GIT_USER_EMAIL`: Global `user.name` and `user.email` values to save into the `~/.gitconfig` [Configuration variables file](https://git-scm.com/docs/git-config#_configuration_file) via `git config --global ...`.
- `GIT_CREDENTIALS`: GitHub personal access token as used by [git-credential-store](https://git-scm.com/docs/git-credential-store). Saved into `~/.git-credentials`.

# Documentation

- [ecs.md](docs/ecs.md): Documents the lab's [ECS](https://aws.amazon.com/ecs/) setup.
