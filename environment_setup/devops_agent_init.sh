#!/bin/sh

#strict mode, fail on error
set -euo pipefail

echo "start"

echo "install Ubuntu packages"

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
export DEBIAN_FRONTEND=noninteractive
echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

apt-get update \
&& apt-get install -y --no-install-recommends \
        ca-certificates \
        jq \
        docker.io

echo "Allowing agent to run docker"

usermod -aG docker azuredevopsuser

echo "Installing Azure CLI"

curl -sL https://aka.ms/InstallAzureCLIDeb | bash

echo "install VSTS Agent"

cd /home/azuredevopsuser
mkdir -p agent
cd agent

AGENTRELEASE="$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')"
AGENTURL="https://vstsagentpackage.azureedge.net/agent/${AGENTRELEASE}/vsts-agent-linux-x64-${AGENTRELEASE}.tar.gz"
echo "Release "${AGENTRELEASE}" appears to be latest" 
echo "Downloading..."
wget -O agent_package.tar.gz ${AGENTURL} 

for agent in $4; do
  agent_dir="agent-$agent"
  mkdir -p "$agent_dir"
  pushd "$agent_dir"
    echo "installing agent $agent"
    tar zxvf ../agent_package.tar.gz
    chmod -R 777 .
    echo "extracted"
    ./bin/installdependencies.sh
    echo "dependencies installed"
    sudo -u azuredevopsuser ./config.sh --unattended --url "$1" --auth pat --token "$2" --pool "$3" --agent "$agent" --acceptTeeEula --work ./_work --runAsService
    echo "configuration done"
    ./svc.sh install
    echo "service installed"
    ./svc.sh start
    echo "service started"
    echo "config done"
  popd
done
