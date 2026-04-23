#!/usr/bin/env bash
# =============================================================================
# update-image-tag.sh
#
# Updates the container image URI for a named container in a Kubernetes
# Deployment manifest using yq (YAML-aware — no fragile sed regex).
#
# FIX MEDIUM-07: Replaced broad sed regex with yq to target container by name.
# FIX MEDIUM-08: Added trap EXIT for temp file cleanup.
#
# Usage:
#   ./update-image-tag.sh --manifest <path> --image-uri <uri> [--container <name>]
#
# Arguments:
#   --manifest    Path to the Kubernetes Deployment YAML file  (required)
#   --image-uri   Full image URI with tag                      (required)
#   --container   Container name to update  [default: myapp]   (optional)
#
# Example:
#   ./update-image-tag.sh \
#     --manifest   apps/myapp/deployment.yaml \
#     --image-uri  123456789.dkr.ecr.us-east-1.amazonaws.com/gitops-eks/myapp:sha-abc1234 \
#     --container  myapp
# =============================================================================

set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '3,20p'
  exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────
MANIFEST=""
IMAGE_URI=""
CONTAINER_NAME="myapp"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)    MANIFEST="$2";        shift 2 ;;
    --image-uri)   IMAGE_URI="$2";       shift 2 ;;
    --container)   CONTAINER_NAME="$2";  shift 2 ;;
    -h|--help)     usage ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "${MANIFEST}"   ]] && { echo "ERROR: --manifest is required."   >&2; usage; }
[[ -z "${IMAGE_URI}"  ]] && { echo "ERROR: --image-uri is required."  >&2; usage; }
[[ ! -f "${MANIFEST}" ]] && { echo "ERROR: File not found: ${MANIFEST}" >&2; exit 1; }

if [[ "${IMAGE_URI}" != *:* ]]; then
  echo "ERROR: --image-uri must include a tag (repo:tag). Got: ${IMAGE_URI}" >&2
  exit 1
fi

# ── Ensure yq is available ────────────────────────────────────────────────────
if ! command -v yq &>/dev/null; then
  echo "INFO: yq not found — installing yq v4 to /usr/local/bin/yq ..."
  YQ_VERSION="v4.44.3"
  YQ_BINARY="yq_linux_amd64"
  curl -sSfL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" \
    -o /tmp/yq
  chmod +x /tmp/yq
  # Install to a writable location (works in CI and locally)
  if [[ -w /usr/local/bin ]]; then
    mv /tmp/yq /usr/local/bin/yq
  else
    sudo mv /tmp/yq /usr/local/bin/yq
  fi
  echo "INFO: yq installed successfully."
fi

# ── Temp file with guaranteed cleanup ────────────────────────────────────────
TMPFILE="$(mktemp)"
trap 'rm -f "${TMPFILE}"' EXIT   # FIX MEDIUM-08: always clean up

# ── Update the image for the specific container ───────────────────────────────
# FIX MEDIUM-07: yq targets container by name — safe with multi-container pods
yq e \
  "(.spec.template.spec.containers[] | select(.name == \"${CONTAINER_NAME}\") | .image) = \"${IMAGE_URI}\"" \
  "${MANIFEST}" > "${TMPFILE}"

# ── Verify the substitution succeeded ────────────────────────────────────────
if ! grep -qF "${IMAGE_URI}" "${TMPFILE}"; then
  echo "ERROR: Could not find container '${CONTAINER_NAME}' in ${MANIFEST}." >&2
  echo "       Available containers:" >&2
  yq e '.spec.template.spec.containers[].name' "${MANIFEST}" >&2
  exit 1
fi

mv "${TMPFILE}" "${MANIFEST}"

echo "SUCCESS: Updated container '${CONTAINER_NAME}' in ${MANIFEST}"
echo "         New image: ${IMAGE_URI}"
