FROM ghcr.io/actions/actions-runner:2.331.0
COPY entrypoint.sh ./
RUN    mkdir -p .runner_config .runner_logs \
    && sudo ln -sf /usr/bin/python3 /usr/bin/python \
    && sudo apt-get update -qq \
    && sudo apt-get install -qq -y \
            automake binutils-dev cmake curl git-lfs libssl-dev libstdc++-9-dev \
            libstdc++-10-dev libstdc++-11-dev libstdc++-12-dev libstdc++-13-dev \
            libstdc++-14-dev libtool pipx pkg-config python3-pip rename tini wget \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && curl -sSL -o "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install gh -y \
    && sudo apt-get clean \
    && sudo curl -sSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture) \
    && sudo chmod +x /usr/local/bin/yq \
    && sudo rm -rf /var/lib/apt/lists/* \
    && sudo chmod +x entrypoint.sh
USER root
ENTRYPOINT [ "/usr/bin/tini", "--" ,"./entrypoint.sh" ]
