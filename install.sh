#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "arch: $(arch)"

install_dependencies() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -p "Would you like to customize the Panel Port settings? (If not, random port will be applied) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -p "Please set up the panel port: " config_port
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    # checks if the installation backup dir exist. if existed then ask user if they want to restore it else continue installation.
    if [[ -e /usr/local/x-ui-backup/ ]]; then
        read -p "Failed installation detected. Do you want to restore previously installed version? [y/n]? ": restore_confirm
        if [[ "${restore_confirm}" == "y" || "${restore_confirm}" == "Y" ]]; then
            systemctl stop x-ui
            mv /usr/local/x-ui-backup/x-ui.db /etc/x-ui/ -f
            mv /usr/local/x-ui-backup/ /usr/local/x-ui/ -f
            systemctl start x-ui
            echo -e "${green}previous installed x-ui restored successfully${plain}, it is up and running now..."
            exit 0
        else
            echo -e "Continuing installing x-ui ..."
        fi
    fi

    cd /usr/local/

    # Repository configuration - Change this to your repository
    GITHUB_USER="hamedbaftam"
    GITHUB_REPO="x-ui"
    GITHUB_BRANCH="main"
    
    if [ $# == 0 ]; then
        # Try to get latest release first
        last_version=$(curl -Ls "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${yellow}No release found, building from source...${plain}"
            INSTALL_FROM_SOURCE=true
        else
            echo -e "Got x-ui latest version: ${last_version}, beginning the installation..."
            wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz
            if [[ $? -ne 0 ]]; then
                echo -e "${yellow}Downloading release failed, building from source...${plain}"
                INSTALL_FROM_SOURCE=true
            else
                INSTALL_FROM_SOURCE=false
            fi
        fi
    else
        last_version=$1
        url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${yellow}Downloading release failed, building from source...${plain}"
            INSTALL_FROM_SOURCE=true
        else
            INSTALL_FROM_SOURCE=false
        fi
    fi
    
    # If release download failed, build from source
    if [[ "$INSTALL_FROM_SOURCE" == "true" ]]; then
        echo -e "${green}Building x-ui from source (${GITHUB_USER}/${GITHUB_REPO})...${plain}"
        
        # Check if Go is installed
        if ! command -v go &> /dev/null; then
            echo -e "${yellow}Go not found, installing Go...${plain}"
            GO_VERSION="1.25.1"
            ARCH=$(arch)
            case "${ARCH}" in
                x86_64 | x64 | amd64) GO_ARCH="amd64" ;;
                armv8* | armv8 | arm64 | aarch64) GO_ARCH="arm64" ;;
                armv7* | armv7 | arm) GO_ARCH="armv7" ;;
                *) GO_ARCH="amd64" ;;
            esac
            
            cd /tmp
            wget https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
            rm -rf /usr/local/go
            tar -C /usr/local -xzf go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
            export PATH=$PATH:/usr/local/go/bin
            rm go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
        fi
        
        # Clone and build
        BUILD_DIR="/tmp/x-ui-build"
        rm -rf ${BUILD_DIR}
        git clone --depth 1 -b ${GITHUB_BRANCH} https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git ${BUILD_DIR}
        cd ${BUILD_DIR}
        
        # Build x-ui
        go build -ldflags "-w -s" -o x-ui main.go
        
        # Download xray binary
        XRAY_ARCH_NAME=$(arch)
        case "${XRAY_ARCH_NAME}" in
            x86_64 | x64 | amd64) 
                XRAY_FILENAME="Xray-linux-64.zip"
                XRAY_BINARY_NAME="xray-linux-amd64"
                ;;
            armv8* | armv8 | arm64 | aarch64) 
                XRAY_FILENAME="Xray-linux-arm64-v8a.zip"
                XRAY_BINARY_NAME="xray-linux-arm64"
                ;;
            armv7* | armv7 | arm) 
                XRAY_FILENAME="Xray-linux-arm32-v7a.zip"
                XRAY_BINARY_NAME="xray-linux-armv7"
                ;;
            *) 
                XRAY_FILENAME="Xray-linux-64.zip"
                XRAY_BINARY_NAME="xray-linux-amd64"
                ;;
        esac
        
        mkdir -p bin
        cd bin
        XRAY_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        echo -e "${yellow}Downloading Xray ${XRAY_VERSION} (${XRAY_FILENAME})...${plain}"
        wget -N --no-check-certificate https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/${XRAY_FILENAME}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download Xray binary${plain}"
            cd ..
            rm -rf ${BUILD_DIR}
            exit 1
        fi
        unzip -q ${XRAY_FILENAME}
        rm ${XRAY_FILENAME}
        mv xray ${XRAY_BINARY_NAME}
        chmod +x ${XRAY_BINARY_NAME}
        cd ..
        
        # Create tarball in /usr/local
        cd /usr/local
        tar czf x-ui-linux-$(arch).tar.gz -C ${BUILD_DIR} x-ui x-ui.sh x-ui.service bin/
        rm -rf ${BUILD_DIR}
        echo -e "${green}Build completed successfully!${plain}"
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        mv /usr/local/x-ui/ /usr/local/x-ui-backup/ -f
        if [[ -e /etc/x-ui/x-ui.db ]]; then
            cp /etc/x-ui/x-ui.db /usr/local/x-ui-backup/ -f
        fi
    fi

    cd /usr/local
    if [[ ! -f x-ui-linux-$(arch).tar.gz ]]; then
        echo -e "${red}Build tarball not found!${plain}"
        exit 1
    fi
    
    mkdir -p x-ui
    tar zxvf x-ui-linux-$(arch).tar.gz -C x-ui
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv7" ]]; then
        if [[ -f bin/xray-linux-armv7 ]]; then
            mv bin/xray-linux-armv7 bin/xray-linux-arm
            chmod +x bin/xray-linux-arm
        fi
    fi
    
    # Make sure binaries are executable
    chmod +x x-ui
    if ls bin/xray-linux-* 1> /dev/null 2>&1; then
        chmod +x bin/xray-linux-*
    fi
    cp -f x-ui.service /etc/systemd/system/
    # Download x-ui.sh from your repository
    GITHUB_USER="hamedbaftam"
    GITHUB_REPO="x-ui"
    GITHUB_BRANCH="main"
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    rm /usr/local/x-ui-backup/ -rf
    #echo -e "If it is a new installation, the default web port is ${green}54321${plain}, The username and password are ${green}admin${plain} by default"
    #echo -e "Please make sure that this port is not occupied by other procedures,${yellow} And make sure that port 54321 has been released${plain}"
    #    echo -e "If you want to modify the 54321 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released"
    #echo -e ""
    #echo -e "If it is updated panel, access the panel in your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} installation finished, it is up and running now..."
    echo -e ""
    echo -e "You may access the Panel with following URL(s):${yellow}"
    /usr/local/x-ui/x-ui uri
    echo -e "${plain}"
    echo "X-UI Control Menu Usage"
    echo "------------------------------------------"
    echo "SUBCOMMANDS:"
    echo "x-ui              - Admin Management Script"
    echo "x-ui start        - Start"
    echo "x-ui stop         - Stop"
    echo "x-ui restart      - Restart"
    echo "x-ui status       - Current Status"
    echo "x-ui settings     - Current Settings"
    echo "x-ui enable       - Enable Autostart on OS Startup"
    echo "x-ui disable      - Disable Autostart on OS Startup"
    echo "x-ui log          - Check Logs"
    echo "x-ui update       - Update"
    echo "x-ui install      - Install"
    echo "x-ui uninstall    - Uninstall"
    echo "x-ui help         - Control Menu Usage"
    echo "------------------------------------------"
}

echo -e "${green}Running...${plain}"
install_dependencies
install_x-ui $1
