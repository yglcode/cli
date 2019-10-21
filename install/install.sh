#!/usr/bin/env bash

# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
# ------------------------------------------------------------

# Dapr CLI location
: ${DAPR_INSTALL_DIR:="$HOME/.dapr"}

DAPR_INSTALL_BIN="$DAPR_INSTALL_DIR/bin"
DAPR_INSTALL_DOWNLOADS="$DAPR_INSTALL_DIR/downloads"
if [ ! -d $DAPR_INSTALL_DIR ]; then
    mkdir -p $DAPR_INSTALL_DIR
fi
if [ ! -d $DAPR_INSTALL_BIN ]; then
    mkdir -p $DAPR_INSTALL_BIN
fi
if [ ! -d $DAPR_INSTALL_DOWNLOADS ]; then
    mkdir -p $DAPR_INSTALL_DOWNLOADS
fi

# Http request CLI
DAPR_HTTP_REQUEST_CLI=curl

# GitHub Organization and repo name to download release
GITHUB_ORG=dapr
GITHUB_REPO=cli

# Dapr CLI filename
DAPR_CLI_FILENAME=dapr

DAPR_CLI_FILE="${DAPR_INSTALL_BIN}/${DAPR_CLI_FILENAME}"

getSystemInfo() {
    ARCH=$(uname -m)
    case $ARCH in
        armv7*) ARCH="arm";;
        aarch64) ARCH="arm64";;
        x86_64) ARCH="amd64";;
    esac

    OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')
}

verifySupported() {
    local supported=(darwin-amd64 linux-amd64 linux-arm linux-arm64)
    local current_osarch="${OS}-${ARCH}"

    for osarch in "${supported[@]}"; do
        if [ "$osarch" == "$current_osarch" ]; then
            echo "Your system is ${OS}_${ARCH}"
            return
        fi
    done

    echo "No prebuilt binary for ${current_osarch}"
    exit 1
}

checkHttpRequestCLI() {
    if type "curl" > /dev/null; then
        DAPR_HTTP_REQUEST_CLI=curl
    elif type "wget" > /dev/null; then
        DAPR_HTTP_REQUEST_CLI=wget
    else
        echo "Either curl or wget is required"
        exit 1
    fi
}

checkExistingDapr() {
    if [ -f "$DAPR_CLI_FILE" ]; then
        echo -e "\nDapr CLI is detected:"
        $DAPR_CLI_FILE --version
        echo -e "Reinstalling Dapr CLI - ${DAPR_CLI_FILE}...\n"
    else
        echo -e "Installing Dapr CLI...\n"
    fi
}

getLatestRelease() {
    local daprReleaseUrl="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases"
    local latest_release=""

    if [ "$DAPR_HTTP_REQUEST_CLI" == "curl" ]; then
        latest_release=$(curl -s $daprReleaseUrl | grep \"tag_name\" | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    else
        latest_release=$(wget -q --header="Accept: application/json" -O - $daprReleaseUrl | grep \"tag_name\" | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    fi

    ret_val=$latest_release
}

downloadFile() {
    LATEST_RELEASE_TAG=$1

    DAPR_CLI_ARTIFACT="${DAPR_CLI_FILENAME}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${DAPR_CLI_ARTIFACT}"

    # Download artifact
    ARTIFACT_DOWNLOAD_FILE="$DAPR_INSTALL_DOWNLOADS/$DAPR_CLI_ARTIFACT"

    echo "Downloading $DOWNLOAD_URL ..."
    if [ "$DAPR_HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$ARTIFACT_DOWNLOAD_FILE"
    else
        wget -q -O "$ARTIFACT_DOWNLOAD_FILE" "$DOWNLOAD_URL"
    fi

    if [ ! -f "$ARTIFACT_DOWNLOAD_FILE" ]; then
        echo "failed to download $DOWNLOAD_URL ..."
        exit 1
    fi
}

installFile() {
    tar xf "$ARTIFACT_DOWNLOAD_FILE" -C "$DAPR_INSTALL_BIN"

    if [ ! -f "$DAPR_CLI_FILE" ]; then
        echo "Failed to unpack Dapr cli executable."
        exit 1
    fi

    chmod o+x $DAPR_CLI_FILE

    if [ -f "$DAPR_CLI_FILE" ]; then
        echo "$DAPR_CLI_FILENAME installed into $DAPR_INSTALL_BIN successfully."
        echo "Please add $DAPR_INSTALL_BIN to your PATH."
        INIT_SCRIPT="$HOME/.bashrc"
        if [ -f "$INIT_SCRIPT" ]; then
	    UPDATED_PATH=$(bash -i -c 'echo $PATH')
	    if [[ "$UPDATED_PATH" != *"$DAPR_INSTALL_BIN"* ]]; then
                echo "export PATH=$DAPR_INSTALL_BIN:$PATH" >> $INIT_SCRIPT
            fi
        fi

        $DAPR_CLI_FILE --version
    else 
        echo "Failed to install $DAPR_CLI_FILENAME"
        exit 1
    fi
}

fail_trap() {
    result=$?
    if [ "$result" != "0" ]; then
        echo "Failed to install Dapr CLI"
        echo "For support, go to https://dapr.io"
    fi
    cleanup
    exit $result
}

cleanup() {
    if [ -f "${ARTIFACT_DOWNLOAD_FILE}" ]; then
	echo "remove $ARTIFACT_DOWNLOAD_FILE"
        rm "$ARTIFACT_DOWNLOAD_FILE"
    fi
}

installCompleted() {
    if [[ "$(id -Gn)" != *docker* ]]; then
        echo "To avoid sudo, please add user to group \"docker\""
    fi
    echo -e "\nTo get started with Dapr, please visit https://github.com/dapr/docs/tree/master/getting-started"
}

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
trap "fail_trap" EXIT

getSystemInfo
verifySupported
checkExistingDapr
checkHttpRequestCLI

getLatestRelease
downloadFile $ret_val
installFile
cleanup

installCompleted
