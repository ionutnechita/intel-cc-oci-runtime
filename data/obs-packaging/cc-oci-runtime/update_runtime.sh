#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-oci-runtime
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

CC_VERSIONS_FILE="../../../configure.ac"
DEFAULT_VERSION=$(sed -n -e 's/AC_INIT(.*,[ ]*\[\(.*\)\])/\1/p' ${CC_VERSIONS_FILE})
VERSION=${1:-$DEFAULT_VERSION}
hash_tag=$(git log --oneline --pretty="%H %d" --decorate --tags --no-walk | grep $VERSION| awk '{print $1}')
# If there is no tag matching $VERSION we'll get $VERSION as the reference
[ -z "$hash_tag" ] && hash_tag=$VERSION || :

# load versions
source ../../../versions.txt

OBS_PUSH=${OBS_PUSH:-false}
OBS_RUNTIME_REPO=${OBS_RUNTIME_REPO:-home:clearlinux:preview:clear-containers-staging/cc-oci-runtime}

echo "Running: $0 $@"
echo "Update cc-oci-runtime $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-oci-runtime ($VERSION) stable; urgency=medium

  * Update cc-oci-runtime $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

sed -e "s/@VERSION@/$VERSION/" \
    -e "s/@qemu_lite_version@/$qemu_lite_fedora_obs_version/" \
    -e "s/@cc_image_version@/$cc_image_fedora_obs_version/" \
    -e "s/@cc_selinux_version@/$cc_selinux_fedora_obs_version/" \
    -e "s/@linux_container_version@/$linux_container_fedora_obs_version/" cc-oci-runtime.spec-template > cc-oci-runtime.spec

sed -e "s/@VERSION@/$VERSION/" \
    -e "s/@qemu_lite_version@/$qemu_lite_ubuntu_obs_version/" \
    -e "s/@cc_image_version@/$cc_image_ubuntu_obs_version/" \
    -e "s/@linux_container_version@/$linux_container_ubuntu_obs_version/" cc-oci-runtime.dsc-template > cc-oci-runtime.dsc

sed -e "s/@VERSION@/$VERSION/" \
    -e "s/@qemu_lite_version@/$qemu_lite_ubuntu_obs_version/" \
    -e "s/@cc_image_version@/$cc_image_ubuntu_obs_version/" \
    -e "s/@linux_container_version@/$linux_container_ubuntu_obs_version/" debian.control-template > debian.control

sed "s/@VERSION@/$VERSION/g;" _service-template > _service
sed "s/@HASH_TAG@/$hash_tag/g;" update_commit_id.patch-template > update_commit_id.patch

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc co "$OBS_RUNTIME_REPO" -o $TMPDIR
    mv cc-oci-runtime.spec \
        cc-oci-runtime.dsc \
        debian.control \
        _service \
        $TMPDIR
    rm $TMPDIR/*.patch
    cp debian.changelog \
        debian.rules \
        debian.compat \
        debian.postinst \
        debian.series \
        *.patch \
        $TMPDIR
    cd $TMPDIR
    osc addremove
    osc commit -m "Update cc-oci-runtime $VERSION: ${hash_tag:0:7}"
fi
