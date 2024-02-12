FROM mcr.microsoft.com/devcontainers/base:bullseye
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git wget tar fzf

# Install zig to bootstrap zigup
RUN wget https://ziglang.org/builds/zig-linux-x86_64-0.12.0-dev.2710+c3eb592a3.tar.xz && \
    tar -xf zig-linux-x86_64-0.12.0-dev.2710+c3eb592a3.tar.xz && \
    cd zig-linux-x86_64-0.12.0-dev.2710+c3eb592a3 && \
    cp -r local ~/.local/bin/ && cp zig ~/.local/bin && chmod +x ~/.local/bin/zig && \
    rm zig-linux-x86_64-0.12.0-dev.2710+c3eb592a3.tar.xz && \
    rm -r zig-linux-x86_64-0.12.0-dev.2710+c3eb592a3

# Install zigup and zls
RUN git clone https://github.com/marler8997/zigup.git && \
    cd zigup && zig build && cp zig-out/bin/zigup ~/.local/bin/ && chmod +x ~/.local/bin/zigup && \
    cd .. && rm -r zigup && zigup 0.12.0-dev.2063+804cee3b9 && \
    git clone https://github.com/zigtools/zls && \
    cd zls && zig build -Doptimize=ReleaseSafe && cp zig-out/bin/zls ~/.local/bin/ && chmod +x ~/.local/bin/zls && \
    && cd .. && rm -r zls
    
