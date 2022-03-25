FROM ubuntu:20.04

LABEL maintainer="im.hanxi@gmail.com"
LABEL version="0.1"
LABEL description="This is Docker Image for skynet-admin"

RUN apt update

RUN DEBIAN_FRONTEND="noninteractive" apt install -y git libssl-dev check libpcre3 libpcre3-dev build-essential libtool \
    automake autoconf pkg-config && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

COPY install.sh /install.sh
RUN sh /install.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 2788
