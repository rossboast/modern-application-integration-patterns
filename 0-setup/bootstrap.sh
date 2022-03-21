#!/bin/sh

# Cloud9 Bootstrap Script
#
# 1. Upgrades Linux & Python packages
# 2. Upgrades to latest AWS CLI
# 3. Upgrades AWS SAM CLI
#
# Usually takes about 5 minutes to complete and requires a restart of the c9 instance to apply disk size changes.

set -eu pipefail

#ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
#CURRENT_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

function _logger() {
    echo -e "$(date) ${YELLOW}[*] $@ ${NC}"
}

function upgrade_sam_cli() {
    _logger "[+] Backing up current SAM CLI"
    cp $(which sam) ~/.sam_old_backup

    _logger "[+] Installing latest SAM CLI"
    curl --no-progress-meter -L https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip -o /tmp/aws-sam-cli-linux-x86_64.zip
    unzip -q -o /tmp/aws-sam-cli-linux-x86_64.zip -d /tmp/sam-installation
    sudo /tmp/sam-installation/install --update
    

    _logger "[+] Updating Cloud9 SAM binary"
    # Allows for local invoke within IDE (except debug run)
    ln -sf $(which sam) ~/.c9/bin/sam
}

function upgrade_existing_packages() {
    _logger "[+] Upgrading system packages"
    if [[ $(command -v apt-get) ]]; then
        sudo apt-get upgrade -y
    elif [[ $(command -v yum) ]]; then
        sudo yum update -y
    fi

    _logger "[+] Upgrading Python pip and setuptools"
    python3 -m pip install --upgrade pip setuptools boto3 --user

    _logger "[+] Installing latest AWS CLI"
    curl --no-progress-meter -L https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
    unzip -q -o /tmp/awscliv2.zip -d /tmp/awscliv2
    sudo /tmp/awscliv2/aws/install --update
    
    _logger "[+] Updating NPM"
    npm install -g npm
}

function install_utility_tools() {
    _logger "[+] Installing jq"
    sudo yum install -y jq
    _logger "[+] Installing wscat"
    npm install -g wscat
}

function increase_c9_disk_size() {
    export instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    python3 expand_c9_disk.py
    if [ $? -eq 0 ]; then
        echo -e "${RED} [!!!!!!!!!] Restarting Cloud9 instance to apply changes... ${NC}"
        _logger "[+] Restarting C9 instance to apply changes"
        sudo reboot
    else
        echo -e "${RED} Error resizing C9 instance disk ${NC}"
        _logger "[+] Error resizing C9 instance disk"
    fi

}

function main() {
    upgrade_existing_packages
    install_utility_tools
    upgrade_sam_cli
    increase_c9_disk_size 
}

main
