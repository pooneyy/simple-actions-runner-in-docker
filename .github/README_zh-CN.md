# Simple Github Action Runner In Docker

![](http://fastly.jsdelivr.net/gh/actions/runner@main/docs/res/github-graph.png)

运行在容器中的简单的自托管 GitHub Actions 运行器。

## 功能

- 支持 Docker-out-of-Docker

  > 某些情况下需要使用 `--privileged` ，比如当你的工作流中使用 `docker/setup-qemu-action`。

- 预安装 `python`  `pip` `pipx`

  > 你可以使用 [actions/setup-python](https://github.com/actions/setup-python) 安装自己所需的 Python 版本

- 预安装 GitHub CLI

### 环境变量
| 参数 | 是否必须 | 说明 |
| --- | --- | --- |
| `ROLE` | 必须 | 用于区分企业、组织与个人仓库<br/>企业为 `enterprises` 组织为 `orgs` ，个人仓库为 `repos`<br/>**REST API** |
| `REPO` | 必须 | 企业格式为`enterpriseName`<br/>组织格式为`orgName`<br/>个人仓库格式为 `owner/repo`<br/>**REST API** |
| `RUNNER_GITHUB_TOKEN` | 必须 | [推荐 Fine-grained PAT](https://github.com/settings/personal-access-tokens/new)。<br />对于企业：<br />**Fine-grained PAT 不能用于企业**<br />OAuth 应用令牌和PAT（classic）需要 `manage_runners:enterprise` 权限。<br />对于组织：<br/>Fine-grained PAT 应具备 Self-hosted runners 的读写权限。<br />OAuth 令牌和PAT（classic）需要 `admin:org` 权限，<br />此外私有组织仓库还需要 `repo` 权限。<br />对于个人仓库：<br/>Fine-grained PAT 应具备 Administration 的读写权限。<br />OAuth 令牌和PAT（classic）需要 `repo` 权限。<br />[如何创建令牌？](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)<br />**REST API** |
| `RUNNER_NAME` | | Runner 名称，留空随机生成。<br />在同一个个人仓库（或企业、组织）中 Runner 名称不能重复，如果输入了当前已经存在的 Runner 名称，则会**强制注销旧 Runner** 并重新创建 Runner |
| `RUNNER_LABELS` | | Runner 标签，填写此项会增加新的标签，若填入多个标签则用半角逗号分隔。<br>示例: `label1,label2` |
| `WORK_FOLDER` | | 工作文件夹，留空随机生成，几乎用不上。 |
| `RUNNER_GROUP` | | Runner 组，默认值为`Default`，具体参见[文档](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access)。 |
| `AUTO_UNREGISTER` | | 是否在容器停止时从 github.com 注销 Runner，默认为 `false`。<br />选择 false 时建议将 /home/runner/.runner_config 映射到本地，这个文件夹保存了 Runner 的登录状态。 |

关于标注了**REST API**的参数，参考[文档](https://docs.github.com/en/enterprise-cloud@latest/rest/actions/self-hosted-runners?apiVersion=2022-11-28)。

### 使用

> [!TIP]
>
> 1. 如果你的宿主机位于中国大陆，在正式部署之前可以先使用下面的命令检查
>
>    ```bash
>    docker run --rm ghcr.io/pooneyy/actions-runner:latest \
>       ./config.sh --check --url <your_repo_url> --pat <you_pat>
>    ```
>
>
> 2. 如果你使用 `docker/setup-buildx-action` 构建镜像，并且计划使用自己的 `buildkitd.toml` 配置文件，请将配置文件映射到容器中，例如：`-v /path/to/buildkitd.toml:/root/.docker/buildx/buildkitd.default.toml` [为什么这么做？](https://docs.docker.com/reference/cli/docker/buildx/create/#buildkitd-config)
>
> 

推荐使用 docker-compose.yml 来启动容器，下面以为本仓库部署自托管 Runner 为例：

```markdown
services:
  actions-runner:
    image: ghcr.io/pooneyy/actions-runner:latest
    container_name: actions-runner
    privileged: false # 特权模式: 遇到权限问题时手动启用
    restart: always
    pull_policy: always
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
      - ./logs:/home/runner/.runner_logs
```
