FROM mcr.microsoft.com/devcontainers/base:bullseye
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git wget tar fzf unzip

USER vscode
RUN mkdir -p /home/vscode/.local/bin && \
    echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> /home/vscode/.zshrc && \
    echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> /home/vscode/.bashrc

ENV PATH "/home/vscode/.local/bin/:$PATH"

WORKDIR "/home/vscode"

# Install zigup and zls
RUN wget https://github.com/marler8997/zigup/releases/download/v2023_07_27/zigup.ubuntu-latest-x86_64.zip && \
    unzip zigup.ubuntu-latest-x86_64.zip && mv zigup ~/.local/bin/ && chmod +x ~/.local/bin/zigup && \
    rm zigup.ubuntu-latest-x86_64.zip && zigup 0.12.0-dev.2063+804cee3b9 && \
    mkdir zls && cd zls && wget https://github.com/zigtools/zls/releases/download/0.11.0/zls-x86_64-linux.tar.gz && \
    tar -xzf zls-x86_64-linux.tar.gz && cp bin/zls ~/.local/bin/ && chmod +x ~/.local/bin/zls && cd .. && rm -r zls
