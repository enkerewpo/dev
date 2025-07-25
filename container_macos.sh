#!/bin/bash

set -euo pipefail

IMAGE_NAME="kernel-dev-macos"
CONTAINER_NAME="kernel-dev-macos-container"
WORKDIR="."
LINUX_SRC_DIR="${WORKDIR}/../linux-6.16-rc7"

show_help() {
    echo "Usage: $0 <command>"
}

build_image() {
    docker build -t ${IMAGE_NAME} -f Dockerfile.macos .
}

run_container() {
    docker run -it --name ${CONTAINER_NAME} \
        -v ${WORKDIR}:/root/workspace \
        -v ${LINUX_SRC_DIR}:/root/linux \
        ${IMAGE_NAME}
}

stop_container() {
    docker stop ${CONTAINER_NAME}
}

remove_container() {
    docker rm ${CONTAINER_NAME}
}

remove_image() {
    docker rmi ${IMAGE_NAME}
}

shallow_init_linux_src_git() {
    # git init submodule linux-git but with depth 10
    # the module is already in .gitmodules
    # show verbose output
    git submodule update --init --remote --progress linux
}

main() {
    case "${1:-help}" in
    help | -h | --help) show_help ;;
    build) build_image ;;
    run) run_container ;;
    stop) stop_container ;;
    remove) remove_container ;;
    remove-image) remove_image ;;
    init-linux-src) shallow_init_linux_src_git ;;
    *)
        echo "unknown command: ${1}"
        show_help
        ;;
    esac
}

main "$@"
