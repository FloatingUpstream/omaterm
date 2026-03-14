#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: container.sh [options]

Build and run an Omaterm container locally.

Options:
  --base <arch|ubuntu>     Base distro to use (default: arch)
  --profile <default|toolchain>
                           Package profile to install (default: default)
  --base-image <image>     Explicit Docker base image override
  --tag <name>             Docker image tag override
  --name <name>            Docker container name override
  --workspace <path>       Host path to mount at /workspace (default: current dir)
  --reset                  Recreate the named container before attaching
  --build-only             Build image only, do not run a container
  --help                   Show this help

Environment:
  OMATERM_REPO             Git URL used to download the repo tarball
  OMATERM_REF              Branch name to download (default: feature/devcontainer-support)
  OMATERM_SOURCE           Source to build from: auto, local, or remote
  OMATERM_BASE             Same as --base
  OMATERM_PROFILE          Same as --profile
  OMATERM_BASE_IMAGE       Same as --base-image
  OMATERM_IMAGE            Same as --tag
  OMATERM_CONTAINER_NAME   Same as --name
  OMATERM_WORKSPACE        Same as --workspace
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

script_dir() {
  local source_path

  source_path="${BASH_SOURCE[0]:-}"
  if [ -n "$source_path" ] && [ -f "$source_path" ]; then
    dirname "$(realpath "$source_path")"
  fi
}

is_local_checkout() {
  local dir="$1"

  [ -n "$dir" ] || return 1
  [ -f "$dir/container.sh" ] || return 1
  [ -f "$dir/Dockerfile" ] || return 1
  [ -f "$dir/install.sh" ] || return 1
  [ -d "$dir/install" ] || return 1
  [ -d "$dir/config" ] || return 1
  [ -d "$dir/bin" ] || return 1
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_.-' '-'
}

default_container_name() {
  local workspace_path workspace_slug workspace_hash

  workspace_path="$(realpath "$1")"
  workspace_slug="$(slugify "$(basename "$workspace_path")")"
  workspace_slug="${workspace_slug#-}"
  workspace_slug="${workspace_slug%-}"
  workspace_hash="$(printf '%s' "$workspace_path" | cksum | cut -d' ' -f1)"

  if [ -z "$workspace_slug" ]; then
    workspace_slug="workspace"
  fi

  printf 'omaterm-%s-%s\n' "$workspace_slug" "$workspace_hash"
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
PROFILE="${OMATERM_PROFILE:-default}"
BASE_IMAGE="${OMATERM_BASE_IMAGE:-}"
IMAGE_TAG="${OMATERM_IMAGE:-}"
WORKSPACE="${OMATERM_WORKSPACE:-$PWD}"
CONTAINER_NAME="${OMATERM_CONTAINER_NAME:-}"
BUILD_ONLY=0
RESET_CONTAINER=0
OMATERM_REPO="${OMATERM_REPO:-https://github.com/FloatingUpstream/omaterm.git}"
OMATERM_REF="${OMATERM_REF:-feature/devcontainer-support}"
OMATERM_SOURCE="${OMATERM_SOURCE:-auto}"

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
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --reset)
      RESET_CONTAINER=1
      shift
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

if [ -z "$CONTAINER_NAME" ]; then
  CONTAINER_NAME="$(default_container_name "$WORKSPACE")"
fi

EXISTING_CONTAINER=0
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  EXISTING_CONTAINER=1
fi

if [ "$RESET_CONTAINER" -eq 1 ] && [ "$EXISTING_CONTAINER" -eq 1 ]; then
  echo "==> Recreating ${CONTAINER_NAME}"
  docker rm -f "$CONTAINER_NAME" >/dev/null
  EXISTING_CONTAINER=0
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

LOCAL_DIR="$(script_dir || true)"
BUILD_CONTEXT=""

case "$OMATERM_SOURCE" in
  auto)
    if is_local_checkout "$LOCAL_DIR"; then
      BUILD_CONTEXT="$LOCAL_DIR"
    fi
    ;;
  local)
    if ! is_local_checkout "$LOCAL_DIR"; then
      echo "Local source requested, but this script is not running from an omaterm checkout" >&2
      exit 1
    fi
    BUILD_CONTEXT="$LOCAL_DIR"
    ;;
  remote)
    ;;
  *)
    echo "Unsupported OMATERM_SOURCE: $OMATERM_SOURCE" >&2
    exit 1
    ;;
esac

if [ "$BUILD_ONLY" -eq 1 ] || [ "$EXISTING_CONTAINER" -eq 0 ]; then
  if [ -z "$BUILD_CONTEXT" ]; then
    REPO_SLUG="$(repo_slug_from_url "$OMATERM_REPO")"
    ARCHIVE_URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${OMATERM_REF}"

    echo "==> Downloading ${REPO_SLUG}@${OMATERM_REF}"
    curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMPDIR" --strip-components=1
    BUILD_CONTEXT="$TMPDIR"
  else
    echo "==> Using local checkout at ${BUILD_CONTEXT}"
  fi

  echo "==> Building ${IMAGE_TAG} from ${BASE_IMAGE}"
  docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    --build-arg OMATERM_PROFILE="$PROFILE" \
    --tag "$IMAGE_TAG" \
    "$BUILD_CONTEXT"
else
  echo "==> Reusing existing container ${CONTAINER_NAME}"
  echo "   Use --reset to rebuild and recreate it"
fi

if [ "$BUILD_ONLY" -eq 1 ]; then
  echo "==> Built ${IMAGE_TAG}"
  exit 0
fi

echo "==> Starting ${IMAGE_TAG}"
echo "   Container: ${CONTAINER_NAME}"
echo "   Attaching to tmux inside the container"
echo "   Prefix: Ctrl-Space (Ctrl-b also works)"
echo "   Detach: Ctrl-b d"

if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  exec </dev/tty >/dev/tty 2>/dev/tty || true
fi

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "==> Creating ${CONTAINER_NAME}"
  docker run -d \
    --name "$CONTAINER_NAME" \
    -v "${WORKSPACE}:/workspace" \
    -w /workspace \
    "$IMAGE_TAG" \
    tail -f /dev/null >/dev/null
elif [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
  echo "==> Starting existing ${CONTAINER_NAME}"
  docker start "$CONTAINER_NAME" >/dev/null
else
  echo "==> Reusing existing ${CONTAINER_NAME}"
fi

exec_flags=()
if [ -t 0 ] && [ -t 1 ]; then
  exec_flags+=(-it)
fi

exec docker exec "${exec_flags[@]}" \
  -e TERM="${TERM:-xterm-256color}" \
  "$CONTAINER_NAME" \
  /bin/bash -l
