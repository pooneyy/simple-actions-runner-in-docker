FROM ghcr.io/actions/actions-runner:2.328.0
WORKDIR /home/runner
USER root
RUN mkdir -p .runner_config && chown runner:docker .runner_config
COPY --chown=runner:docker launcher.sh ./
RUN apt-get update && apt-get install -y tini && apt-get clean
USER runner
RUN chmod +x launcher.sh
ENTRYPOINT [ "/usr/bin/tini", "--" ,"./launcher.sh" ]
