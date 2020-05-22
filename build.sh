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

        # DOWNLOAD ROOTFS
        wget -nv "${ROOTFS_URL}" -O "${_PLATFORM}/rootfs.tar.gz" # rootfs
    done

    # BUILD AND PUSH TO DOCKER

    # CONFIGURE DISTRO
    if [ "$_RELEASE" = "xenial" ]; then
    
        cat >> "Dockerfile" <<'EOF'
# delete all the apt list files since they're big and get stale quickly
RUN rm -rf /var/lib/apt/lists/*
# this forces "apt-get update" in dependent images, which is also good
# (see also https://bugs.launchpad.net/cloud-images/+bug/1699913)
EOF
    else 
        cat >> "Dockerfile" <<'EOF'
# verify that the APT lists files do not exist
RUN [ -z "$(apt-get indextargets)" ]
# (see https://bugs.launchpad.net/cloud-images/+bug/1699913)
EOF
    fi

    cat >> "Dockerfile" <<'EOF'
# a few minor docker-specific tweaks
# see https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap
RUN set -xe \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L40-L48
	&& echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
	&& echo 'exit 101' >> /usr/sbin/policy-rc.d \
	&& chmod +x /usr/sbin/policy-rc.d \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L54-L56
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& cp -a /usr/sbin/policy-rc.d /sbin/initctl \
	&& sed -i 's/^exit.*/exit 0/' /sbin/initctl \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L71-L78
	&& echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L85-L105
	&& echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
	&& echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
	&& echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L109-L115
	&& echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L118-L130
	&& echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
	\
# https://github.com/docker/docker/blob/9a9fc01af8fb5d98b8eec0740716226fadb3735c/contrib/mkimage/debootstrap#L134-L151
	&& echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests

# make systemd-detect-virt return "docker"
# See: https://github.com/systemd/systemd/blob/aa0c34279ee40bce2f9681b496922dedbadfca19/src/basic/virt.c#L434
RUN mkdir -p /run/systemd && echo 'docker' > /run/systemd/container
EOF

    # ADD S6-OVERLAY
    echo "# ADD S6-OVERLAY" >> "Dockerfile"
    echo "ADD ${S6_URL} /tmp/s6-overlay.tar.gz " >> "Dockerfile"
    echo "RUN tar xzf /tmp/s6-overlay.tar.gz -C / --exclude='./bin' && tar xzf /tmp/s6-overlay.tar.gz -C /usr ./bin" >> "Dockerfile"

    cat >> "Dockerfile" <<'EOF'
# INIT S6-OVERLAY
ENTRYPOINT ["/init"]

# SET DEFAULT COMMAND
CMD ["/bin/bash"]
EOF

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
