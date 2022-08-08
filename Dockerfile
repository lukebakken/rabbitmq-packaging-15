## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
#
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
#
## The Original Code is RabbitMQ.
#
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2018-2022 VMware, Inc. or its affiliates.

FROM buildpack-deps:bullseye

ENV LANG='C.UTF-8'

# Enable backports.
RUN echo 'deb http://httpredir.debian.org/debian buster-backports main' \
    >> /etc/apt/sources.list.d/backports.list

# Prerequisites to mess with packages.
RUN apt-get clean && \
    apt-get update && \
    apt-get install -y -V --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      wget \
      debconf-utils \
      gnupg

# Our own rabbitmq-erlang repository to provision Erlang.
RUN echo 'deb https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/debian buster main' > /etc/apt/sources.list.d/rabbitmq-erlang.list && \
    wget -O- https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | apt-key add -

# We need to set an APT preference to make sure $ERLANG_VERSION is
# used for all erlang* packages. Without this, apt-get(1) would try to
# install dependencies using the latest version. This would conflict
# with the strict pinning in all packages, and thus fail.
RUN ERLANG_VERSION=1:25.0-1 && \
    echo 'Package: erlang*' > /etc/apt/preferences.d/erlang && \
    echo "Pin: version $ERLANG_VERSION" >> /etc/apt/preferences.d/erlang && \
    echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/erlang

# --------------------------------------------------------------------
# Packages to build RabbitMQ.
# --------------------------------------------------------------------

RUN apt-get clean && \
    apt-get update && \
    apt-get install -y -V --fix-missing --no-install-recommends \
      build-essential \
      clang \
      curl \
      erlang-base \
      erlang-nox \
      erlang-dev \
      erlang-src \
      erlang-common-test \
      erlang-dialyzer \
      libcurl3-gnutls \
      man \
      mandoc \
      openssh-client \
      rsync \
      xmlto \
      xsltproc \
      zip \
      unzip

RUN apt-get install -y -V --fix-missing --no-install-recommends \
      -t buster-backports \
      git

# Verify the version of the installed Erlang packages.
# The version was pinned above, but if that specific version is unavailable,
# the latest version will be installed, which we don't want.
RUN set -xe \
    && installed_version=$(dpkg -s erlang-nox | grep -E '^Version:' | awk '{ print $2; }') \
    && wanted_version=$(awk '/^Pin:/ { print $3; }' < /etc/apt/preferences.d/erlang) \
    && test "$installed_version" = "$wanted_version"

RUN set -xe \
    && REBAR3_VERSION="3.18.0" \
    && REBAR3_DOWNLOAD_URL="https://github.com/erlang/rebar3/releases/download/${REBAR3_VERSION}/rebar3" \
    && REBAR3_DOWNLOAD_SHA256="f3e2641be923ce23076ce4843ee61c63fb392bc6c44dc9d129e4b31f7e136ff0" \
    && curl -fSL -o "rebar3-${REBAR3_VERSION}" "$REBAR3_DOWNLOAD_URL" \
    && echo "$REBAR3_DOWNLOAD_SHA256 rebar3-${REBAR3_VERSION}" | sha256sum -c - \
    && mv "rebar3-${REBAR3_VERSION}" /usr/local/bin/rebar3 \
    && chmod +x /usr/local/bin/rebar3

# Compile Elixir from source so that we know for sure what version was used to built it.
# Elixir's bin and lib are installed under /usr/local/bin and /usr/local/lib.
RUN set -xe \
  && ELIXIR_VERSION="1.13.4" \
  && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/refs/tags/v${ELIXIR_VERSION}.zip" \
  && ELIXIR_DOWNLOAD_SHA256="b7f5f38c049084cd30852f6990e478862f156e53aee748f9d9a421521afca940" \
  && curl -fSL -o elixir-source.zip $ELIXIR_DOWNLOAD_URL \
  && echo "$ELIXIR_DOWNLOAD_SHA256 elixir-source.zip" | sha256sum -c - \
  && unzip -d /tmp/elixir-source elixir-source.zip \
  && make -C "/tmp/elixir-source/elixir-${ELIXIR_VERSION}" \
  && mv /tmp/elixir-source/elixir-${ELIXIR_VERSION}/bin/* /usr/local/bin/ \
  && mv /tmp/elixir-source/elixir-${ELIXIR_VERSION}/lib/* /usr/local/lib/ \
  && mv /tmp/elixir-source/elixir-${ELIXIR_VERSION}/man/* /usr/local/man/ \
  && rm -rf elixir-source.zip /tmp/elixir-source

# Put erl_call(1) in the $PATH.
RUN ln -fs /usr/lib/erlang/lib/erl_interface-*/bin/erl_call /usr/bin/erl_call

# --------------------------------------------------------------------
# Packages used to test RabbitMQ.
# --------------------------------------------------------------------

RUN echo 'slapd    slapd/internal/generated_adminpw    password   rabbitmq' | debconf-set-selections && \
    echo 'slapd    slapd/internal/adminpw    password   rabbitmq' | debconf-set-selections && \
    echo 'slapd    slapd/password2    password   rabbitmq' | debconf-set-selections && \
    echo 'slapd    slapd/password1    password   rabbitmq' | debconf-set-selections && \
    echo 'slapd    slapd/backend    select    HDB' | debconf-set-selections

RUN apt-get install -y -V --fix-missing --no-install-recommends \
      ldap-utils \
      netcat \
      python-dev \
      python3-simplejson \
      python3 \
      python3-dev \
      python3-pip \
      python3-setuptools \
      slapd \
      daemonize

RUN git clone --depth 1 https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr && \
    cd .. && \
    rm -rf bats-core

RUN apt-get install -y -V --fix-missing --no-install-recommends \
      ca-certificates-java \
      openjdk-11-jre-headless \
      openjdk-11-jdk-headless

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/

# Install Java tools separately to be sure it picks the version of
# OpenJDK installed above.
RUN apt-get install -y -V --fix-missing --no-install-recommends \
      maven

# .NET Core 6.0 requirements (https://www.microsoft.com/net/core#linuxdebian).
RUN apt-get install -y -V --fix-missing --no-install-recommends \
        apt-transport-https

# .NET Core 6.0 (https://www.microsoft.com/net/core#linuxdebian).
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg && \
    sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-buster-prod buster main" > /etc/apt/sources.list.d/dotnetdev.list'

# .NET Core 6.0 (https://www.microsoft.com/net/core#linuxdebian).
RUN apt-get update && \
    apt-get install -y -V --fix-missing --no-install-recommends \
    gettext \
    libunwind8 \
    dotnet-sdk-6.*

# .NET Core 6.0 warmup
RUN mkdir warmup \
    && cd warmup \
    && dotnet new console \
    && cd .. \
    && rm -rf warmup \
    && rm -rf /tmp/NuGetScratch

# Terraform, used to run some testsuites on AWS.
RUN TERRAFORM_VERSION=0.12.24 && \
    wget -O terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    unzip terraform.zip && \
    mv terraform /usr/bin && \
    rm -f terraform.zip && \
    terraform --version

# AWS cli's, used to run some testsuites on AWS.
RUN AWS_CLI_VERSION=2.1.38 && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    aws --version

ADD rabbitmq-server-buildenv_linux-erlang-25.0-elixir-latest-dockerfile/docker/rabbitmq-server-buildenv/aws.pgp /tmp/aws.pgp
RUN ECS_CLI_VERSION=1.21.0 && \
    curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-v${ECS_CLI_VERSION} && \
    gpg --import /tmp/aws.pgp && \
    rm /tmp/aws.pgp && \
    curl -Lo ecs-cli.asc https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-v${ECS_CLI_VERSION}.asc && \
    gpg --verify ecs-cli.asc /usr/local/bin/ecs-cli && \
    chmod +x /usr/local/bin/ecs-cli && \
    ecs-cli --version

# https://github.com/aws/aws-cli/issues/5038
RUN apt-get install -y -V --fix-missing --no-install-recommends \
      less

# --------------------------------------------------------------------
# Packages for querying Github.
# --------------------------------------------------------------------

RUN pip3 install PyGithub

# --------------------------------------------------------------------
# Packages to build RabbitMQ packages.
# --------------------------------------------------------------------

# FIXME: We shouldn't use this image to build packages, but regular
# Debian/Fedora/CentOS images.
RUN apt-get install -y -V --fix-missing --no-install-recommends \
      nsis \
      rpm \
      tofrodos

# --------------------------------------------------------------------
# Packages to help debugging from the container directly.
# --------------------------------------------------------------------

RUN apt-get install -y -V --fix-missing --no-install-recommends \
      elinks \
      vim
