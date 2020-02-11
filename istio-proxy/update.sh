#!/bin/bash

function usage() {
    echo "Usage: $0 [-p <SHA of istio-proxy> -o <SHA of proxy-openssl>]"
    echo
    exit 0
}

while getopts ":i:" opt; do
    case ${opt} in
        p) PROXY_SHA="${OPTARG}";;
        o) PROXY_OPENSSL_SHA="${OPTARG}";;
        *) usage;;
    esac
done

[[ -z "${PROXY_SHA}" ]] && PROXY_SHA="$(grep '%global proxy_git_commit ' istio-proxy.spec | cut -d' ' -f3)"
[[ -z "${PROXY_OPENSSL_SHA}" ]] && PROXY_OPENSSL_SHA="$(grep '%global proxy_openssl_git_commit ' istio-proxy.spec | cut -d' ' -f3)"


function update_commit() {
    local proxy_sha=$1
    local proxy_openssl_sha=$2

    echo
    echo "Updating spec file with Proxy SHA: ${proxy_sha}"
    sed -i "s/%global proxy_git_commit .*/%global proxy_git_commit ${proxy_sha}/" istio-proxy.spec

    echo "Updating spec file with Proxy OpenSSL SHA: ${proxy_openssl_sha}"
    sed -i "s/%global proxy_openssl_git_commit .*/%global proxy_openssl_git_commit ${proxy_openssl_sha}/" istio-proxy.spec
}

#update_bazel_version checks istio-proxy.spec for the specified bazel version and updates common.sh
function update_bazel_version() {
    bazelVersion=$(grep 'BuildRequires:  bazel =' istio-proxy.spec | cut -d ' ' -f5)
    sed -i "s/^[ ]*BAZEL_VERSION=.*/  BAZEL_VERSION=${bazelVersion}/" common.sh
}

function new_sources() {
    local filename=$1
    echo
    echo "Updating sources file with ${filename}"

    md5sum ${filename} > sources
    local checksum=$(awk '{print $1}' sources)

    sed -i "s/%global checksum .*/%global checksum ${checksum}/" istio-proxy.spec

    local checksumFilename=istio-proxy.${checksum}.tar.xz
    mv $filename $checksumFilename
    sed -i "s/${filename}/${checksumFilename}/" sources
}

function get_sources() {
    local proxy_sha=$1
    local proxy_openssl_sha=$2

    FETCH_DIR=/tmp CREATE_TARBALL=true PROXY_GIT_COMMIT_HASH=${proxy_sha} \
    ISTIO_PROXY_OPENSSL_GIT_COMMIT_HASH=${proxy_openssl_sha} \
    ./fetch.sh

    local tar_name=istio-proxy.${proxy_sha}.tar.xz
    cp -p /tmp/proxy-full.tar.xz ${tar_name}

    new_sources ${tar_name}

}

update_commit "${PROXY_SHA}" "${PROXY_OPENSSL_SHA}"
update_bazel_version
get_sources "${PROXY_SHA}" "${PROXY_OPENSSL_SHA}"
