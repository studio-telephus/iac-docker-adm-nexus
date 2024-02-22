#!/usr/bin/env bash

echo "Install Terraform"

#### The Terraform packages are signed using a private key controlled by HashiCorp, so in most situations the first step would be to configure your system to trust that HashiCorp key for package authentication.
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
#### After registering the key, you can add the official HashiCorp repository to your system:
apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install terraform=1.5.7-1 -y
echo "Exclude terraform package from apt update"
apt-mark hold terraform

echo "To resolve a complaint that it needs the GPG keys in gpg.d directory"
cp /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d

##
echo "Install K8S tools through Arkade"

curl -sLS https://get.arkade.dev | sh
arkade get kubectl kubectx kubens helm
chmod 755 /root/.arkade/bin/*
mv /root/.arkade/bin/* /usr/local/bin/.


curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
install skaffold /usr/local/bin/
rm -f skaffold

echo "Install Bitwarden CLI"
curl -Lo bw.zip https://github.com/bitwarden/clients/releases/download/cli-v2024.1.0/bw-linux-2024.1.0.zip
unzip bw.zip -d .
install bw /usr/local/bin/
rm -f bw bw.zip
