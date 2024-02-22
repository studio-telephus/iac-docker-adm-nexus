#!/usr/bin/env bash

echo "Pre-install system tools"

apt-get update
apt-get install -y \
 vim curl wget htop unzip gnupg2 netcat-traditional \
 bash-completion lsb-release software-properties-common \
 git openssl net-tools
