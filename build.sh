#!/bin/bash

# RELEASES LIST
RELEASES=(
    "trusty=14.04"
    "xenial=16.04"
    "bionic=18.04"
    "eoan=19.10"
    "focal=20.04"
    "groovy=20.10"
)

# ARCHITECTURE LIST
ARCH=(
    "linux/386"
    "linux/amd64"
    "linux/arm/v6"
    "linux/arm/v7"
    "linux/arm64"
    "linux/ppc64le"
)

# REMOVE UNSUPPORTED ARCH FOR RELEASE
# ie: <release name>=<architecture 1>,<architecture 2>,...<architecture n>
UNSUPPORTED=(
    "focal=linux/386"
    "groovy=linux/386"
)
checkSupport() {

    # local var
    local REL=$1
    local _ARCH=("${ARCH[@]}")

    # Search elements in unsupported list
    for ((i = 0; i < ${#UNSUPPORTED[@]}; i++)); do
        # Check if element is equal release
        if [ "$REL" = "${UNSUPPORTED[$i]%%"="*}" ]; then
            UNSUPPORT="${UNSUPPORTED[$i]#*"="}"
            ARCH_REMOVE=(${UNSUPPORT/,/ })

            # Remove from ARCH list
            for item in "${ARCH_REMOVE[@]}"; do
                _ARCH=("${_ARCH[@]/$item/}")
            done
        fi
    done
    echo "${_ARCH[@]}"
}

# S6-OVERLAY
S6_LATEST_VERSION="$(curl -s https://github.com/just-containers/s6-overlay/releases/latest | cut -d '/' -f 8 | cut -d '"' -f 1 | cut -d 'v' -f 2)"
S6_INSTALL_VERSION="${S6_VERSION:-$S6_LATEST_VERSION}"
echo -e "S6-OVERLAY VERSION: ${S6_INSTALL_VERSION} \n"

# DOCKER LOGIN
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin &> /dev/null

# Search release for build
for RELEASE in "${RELEASES[@]}"; do

    _RELEASE="${RELEASE%%"="*}"
    NUM_RELEASE="${RELEASE#*"="}"

    # Check ARCH support
    PLATFORM=($(checkSupport ${_RELEASE}))
    echo "$_RELEASE ($NUM_RELEASE) supported architectures: ${PLATFORM[@]}"

    # Init download of files for ARCH
    for _PLATFORM in "${PLATFORM[@]}"; do

        echo -e "\nDownload files from $_RELEASE ($NUM_RELEASE) FOR $_PLATFORM\n"

        _ARCH=""
        case "$_PLATFORM" in
            linux/386)      _ARCH="i386" ;;
            linux/amd64)    _ARCH="amd64" ;;
            linux/arm/v6)   _ARCH="armhf" ;;
            linux/arm/v7)   _ARCH="armhf" ;;
            linux/arm64)    _ARCH="arm64" ;;
            linux/ppc64le)  _ARCH="ppc64el" ;;
        esac

        # SET ROOTFS DOWNLOAD URL
        ROOTFS_URL="https://partner-images.canonical.com/core/${_RELEASE}/current/ubuntu-${_RELEASE}-core-cloudimg-${_ARCH}-root.tar.gz"

        # SET S6-OVERLAY DOWNLOAD URL
        if [ "${_ARCH}" = "i386" ]; then
            _ARCH="x86"
        fi
        if [ "${_ARCH}" = "arm64" ]; then
            _ARCH="arm"
        fi
        if [ "${_ARCH}" = "ppc64el" ]; then
            _ARCH="ppc64le"
        fi
        S6_URL="https://github.com/just-containers/s6-overlay/releases/download/v${S6_INSTALL_VERSION}/s6-overlay-${_ARCH}.tar.gz"

        # Create dir for platform
        mkdir -p "$_PLATFORM"

        # DOWNLOAD ROOTFS AND S6-OVERLAY
        wget -nv "${ROOTFS_URL}" -O "${_PLATFORM}/rootfs.tar.gz" # rootfs
        wget -nv "${S6_URL}" -O "${_PLATFORM}/s6-overlay.tar.gz" # s6-overlay
    done

    # BUILD AND PUSH TO DOCKER

    # IMAGE CONFIG AND ARGS
    _NAME="${IMAGE_NAME:-$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')}"
    _VERSION="$NUM_RELEASE"
    _BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    _VCS_REF="$(git rev-parse --short HEAD)"
    _PLATFORMS="$( echo ${PLATFORM[@]} | sed 's/ /,/g' )"

    if [ "$_RELEASE" = "${RELEASES[-1]%%"="*}" ]; then
        docker buildx build \
            --push \
	        --build-arg VERSION="${_VERSION}" \
	        --build-arg VCS_REF="${_VCS_REF}" \
	        --build-arg BUILD_DATE="${_BUILD_DATE}" \
	        --platform "${_PLATFORMS}" \
	        -t "${_NAME}:${_RELEASE}" \
            -t "${_NAME}:${NUM_RELEASE}" \
            -t "${_NAME}:latest" \
	        .
    else
        docker buildx build \
            --push \
	        --build-arg VERSION="${_VERSION}" \
	        --build-arg VCS_REF="${_VCS_REF}" \
	        --build-arg BUILD_DATE="${_BUILD_DATE}" \
	        --platform "${_PLATFORMS}" \
	        -t "${_NAME}:${_RELEASE}" \
            -t "${_NAME}:${NUM_RELEASE}" \
	        .
    fi

    # Remove Files
    rm -rf linux
done

# Build Finish
echo -e "Finish!\n"
