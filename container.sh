#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: container.sh [options]

Build and run an Omaterm container locally.

Options:
  --base <arch|ubuntu>     Base distro to use (default: arch)
  --base-image <image>     Explicit Docker base image override
  --tag <name>             Docker image tag override
  --workspace <path>       Host path to mount at /workspace (default: current dir)
  --build-only             Build image only, do not run a container
  --help                   Show this help

Environment:
  OMATERM_REPO             Git URL used to download the repo tarball
  OMATERM_REF              Branch name to download (default: master)
  OMATERM_BASE             Same as --base
  OMATERM_BASE_IMAGE       Same as --base-image
  OMATERM_IMAGE            Same as --tag
  OMATERM_WORKSPACE        Same as --workspace
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

repo_slug_from_url() {
  local repo_url="$1"

  repo_url="${repo_url#git@github.com:}"
  repo_url="${repo_url#https://github.com/}"
  repo_url="${repo_url%.git}"
  printf '%s\n' "$repo_url"
}

base_image_for() {
  case "$1" in
    ubuntu)
      printf 'ubuntu:24.04\n'
      ;;
    arch)
      printf 'archlinux:latest\n'
      ;;
    *)
      echo "Unsupported base: $1" >&2
      exit 1
      ;;
  esac
}

BASE="${OMATERM_BASE:-arch}"
BASE_IMAGE="${OMATERM_BASE_IMAGE:-}"
IMAGE_TAG="${OMATERM_IMAGE:-}"
WORKSPACE="${OMATERM_WORKSPACE:-$PWD}"
BUILD_ONLY=0
OMATERM_REPO="${OMATERM_REPO:-https://github.com/FloatingUpstream/omaterm.git}"
OMATERM_REF="${OMATERM_REF:-master}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      BASE="$2"
      shift 2
      ;;
    --base-image)
      BASE_IMAGE="$2"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command curl
require_command docker
require_command tar

if [ -z "$BASE_IMAGE" ]; then
  BASE_IMAGE="$(base_image_for "$BASE")"
fi

if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="omaterm:${BASE}"
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "Workspace does not exist: $WORKSPACE" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

REPO_SLUG="$(repo_slug_from_url "$OMATERM_REPO")"
ARCHIVE_URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${OMATERM_REF}"

echo "==> Downloading ${REPO_SLUG}@${OMATERM_REF}"
curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMPDIR" --strip-components=1

echo "==> Building ${IMAGE_TAG} from ${BASE_IMAGE}"
docker build \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag "$IMAGE_TAG" \
  "$TMPDIR"

if [ "$BUILD_ONLY" -eq 1 ]; then
  echo "==> Built ${IMAGE_TAG}"
  exit 0
fi

echo "==> Starting ${IMAGE_TAG}"
docker run --rm -it \
  -e TERM="${TERM:-xterm-256color}" \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace \
  "$IMAGE_TAG"
