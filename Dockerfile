FROM ubuntu:20.04

LABEL maintainer="im.hanxi@gmail.com"
LABEL version="0.1"
LABEL description="This is Docker Image for skynet-admin"

RUN apt update

RUN DEBIAN_FRONTEND="noninteractive" apt install -y git libssl-dev check libpcre3 libpcre3-dev build-essential libtool \
    automake autoconf pkg-config mongodb && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

# copy skynet-admin
COPY . /skynet-admin
WORKDIR /skynet-admin
RUN sh install.sh

ENTRYPOINT ["sh", "entrypoint.sh"]

EXPOSE 2788
