# Simple Github Action Runner In Docker

![](http://fastly.jsdelivr.net/gh/actions/runner@main/docs/res/github-graph.png)

[中文](./README_zh-CN.md)

A simple self-hosted actions runner running in a container

## Features

- Supports Docker-in-Docker

### Environment Variables
| Parameter | Required | Description |
| --- | --- | --- |
| `ROLE` | Required | Used to differentiate between enterprise, organization, and personal repositories.<br />Use `enterprises` for enterprise, `orgs` for organization, and `repos` for personal repositories.<br />**REST API** |
| `REPO` | Required | Format for enterprise: `enterpriseName`<br />Format for organization: `orgName`<br />Format for personal repository: `owner/repo`<br />**REST API** |
| `RUNNER_GITHUB_TOKEN` | Required | [Fine-grained PAT is recommended](https://github.com/settings/personal-access-tokens/new).<br />For enterprises:<br />**Fine-grained PAT cannot be used for enterprises**<br />OAuth app tokens and PAT (classic) require the `manage_runners:enterprise` permission.<br />For organizations:<br />Fine-grained PAT should have read and write permissions for Self-hosted runners.<br />OAuth tokens and PAT (classic) require `admin:org` permissions,<br />additionally, `repo` permissions are required for private organization repositories.<br />For personal repositories:<br />Fine-grained PAT should have read and write permissions for Administration.<br />OAuth tokens and PAT (classic) require `repo` permissions.<br />[How to create a token?](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)<br />**REST API** |
| `RUNNER_NAME` | | Runner name. If left empty, it will be randomly generated.<br />Runner names must be unique within the same personal repository (or enterprise/organization). |
| `RUNNER_LABELS` | | Runner labels. Filling this will add new labels..<br />Use commas to separate multiple labels.<br />Example: `label1,label2` |
| `WORK_FOLDER` | | Working directory. If left empty, it will be randomly generated. Rarely needed. |
| `RUNNER_GROUP` | | Runner group. The default value is `Default`. For details, refer to the [documentation](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access). |
| `AUTO_UNREGISTER` | | Whether to unregister the Runner from github.com when the container stops. <br />Default is `false`. It is recommended to map /home/runner/.runner_config <br />to a local when selecting false. This folder saves Runner's login status. |

For parameters marked with **REST API**, refer to the [documentation](https://docs.github.com/en/enterprise-cloud@latest/rest/actions/self-hosted-runners?apiVersion=2022-11-28).

### Usage

> [!TIP]
>
> 1. You can use the command to check before deployment.
>
>     ```bash
>     docker run --rm ghcr.io/actions/actions-runner:latest \
>     	./config.sh --check --url <your_repo_url> --pat <you_pat>
>     ```
>
>     `ghcr.io/actions/actions-runner:latest` is the base image for this project, so you don't have to worry about it taking up valuable drive space.
>       
>       
>
>
> 2. If you are using `docker/setup-buildx-action` to build an image and plan to use your `buildkitd.toml` configuration file, map the configuration file into the container, for example: `-v /path/to/buildkitd.toml:/root/.docker/buildx/buildkitd.default.toml` [Why do this?](https://docs.docker.com/reference/cli/docker/buildx/create/#buildkitd-config)
>
> 

It is recommended to use the docker-compose.yml file to start the container. Below is an example of deploying a self-hosted runner for this repository:

```markdown
services:
  actions-runner:
    image: ghcr.io/pooneyy/actions-runner:latest
    container_name: actions-runner
    privileged: true
    restart: always
    environment:
      ROLE: repos
      REPO: pooneyy/simple-actions-runner-in-docker
      RUNNER_GITHUB_TOKEN: github_pat_XXXXXX
      RUNNER_NAME: runner
      RUNNER_LABELS: label1,label2
      WORK_FOLDER: work
      RUNNER_GROUP: Default
      AUTO_UNREGISTER: false
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config:/home/runner/.runner_config
```
