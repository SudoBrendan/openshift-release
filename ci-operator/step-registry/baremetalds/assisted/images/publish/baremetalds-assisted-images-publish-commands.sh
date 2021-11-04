#!/bin/bash

export HOME=/tmp/home
mkdir -p "$HOME/.docker"
cd "$HOME" || exit 1

if [[ "$JOB_TYPE" != "periodic" ]]; then
    echo "INFO The base branch is ${PULL_BASE_REF}."
fi

# Get IMAGE_REPO if not provided
if [[ -z "$IMAGE_REPO" ]]; then
    echo "INFO Getting destination image repo name from REPO_NAME"
    IMAGE_REPO=${REPO_NAME}
    echo "     Image repo from REPO_NAME is $IMAGE_REPO"
fi
echo "INFO Image repo is $IMAGE_REPO"

current_date=$(date +%F)
echo "INFO Current date is: $current_date"

# Get IMAGE_TAG if not provided
if [[ -z "$IMAGE_TAG" ]]; then
    case "$JOB_TYPE" in
        presubmit)
            echo "INFO Building default image tag for a $JOB_TYPE job"
            IMAGE_TAG="${RELEASE_TAG_PREFIX}-PR${PULL_NUMBER}-${PULL_PULL_SHA}"
            ;;
        postsubmit)
            echo "INFO Building default image tag for a $JOB_TYPE job"
            IMAGE_TAG="${RELEASE_TAG_PREFIX}-${PULL_BASE_SHA}"
            ;;
        periodic)
            echo "INFO Building default image tag for a $JOB_TYPE job"
            IMAGE_TAG="${RELEASE_TAG_PREFIX}-${current_date}"
            ;;
        *)
            echo "ERROR Cannot publish an image from a $JOB_TYPE job"
            exit 1
            ;;
    esac
fi
echo "INFO Image tag is $IMAGE_TAG"

# Setup registry credentials
REGISTRY_TOKEN_FILE="$SECRETS_PATH/$REGISTRY_SECRET/$REGISTRY_SECRET_FILE"

config_file="$HOME/.docker/config.json"
cat "$REGISTRY_TOKEN_FILE" > "$config_file" || {
    echo "ERROR Could not read registry secret file"
    echo "      From: $REGISTRY_TOKEN_FILE"
    echo "      To  : $config_file"
}

if [[ ! -r "$REGISTRY_TOKEN_FILE" ]]; then
    echo "ERROR Registry config file not found: $REGISTRY_TOKEN_FILE"
    echo "      Is the docker/config.json in a different location?"
    exit 1
fi

echo "INFO Login to internal Openshift CI registry"
oc registry login

dry=false
# Check if running in openshift/release
if [[ "$REPO_OWNER" == "openshift" && "$REPO_NAME" == "release" ]]; then
    echo "INFO Running in openshift/release, setting dry-run to true"
    dry=true
fi

# Build destination image reference
DESTINATION_IMAGE_REF="$REGISTRY_HOST/$REGISTRY_ORG/$IMAGE_REPO:$IMAGE_TAG"

echo "INFO Image mirroring command is:"
echo "     oc image mirror ${SOURCE_IMAGE_REF} ${DESTINATION_IMAGE_REF} --dry-run=$dry"

echo "INFO Mirroring Image"
echo "     From   : $SOURCE_IMAGE_REF"
echo "     To     : $DESTINATION_IMAGE_REF"
echo "     Dry Run: $dry"
oc image mirror "$SOURCE_IMAGE_REF" "$DESTINATION_IMAGE_REF" --dry-run=$dry || {
    echo "ERROR Unable to mirror image"
    exit 1
}

echo "INFO Mirroring complete."
