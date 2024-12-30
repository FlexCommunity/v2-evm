FROM mcr.microsoft.com/vscode/devcontainers/base:debian-11

RUN apt-get update \
    && apt-get -y install curl build-essential pkg-config libssl-dev less jq mc iputils-ping \
    && apt-get clean


# Persist bash history
# https://code.visualstudio.com/remote/advancedcontainers/persist-bash-history
ARG USERNAME=vscode

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# --------------

USER vscode
SHELL ["/bin/bash", "--login", "-i", "-c"]

ENV NODE_VERSION 18

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && source $HOME/.nvm/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default


RUN curl -L https://foundry.paradigm.xyz | bash
RUN export PATH="$PATH:/home/vscode/.foundry/bin"
RUN /home/vscode/.foundry/bin/foundryup

RUN npm install --global yarn

WORKDIR /workspaces/v2-evm
COPY ../package.json ../yarn.lock /workspaces/v2-evm/
RUN yarn

# copy config file if it exists
RUN mkdir -p /home/vscode/.tenderly
COPY ../.tenderly/*.yaml  /home/vscode/.tenderly/