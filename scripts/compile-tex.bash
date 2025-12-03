#!/usr/bin/bash

IMAGE_NAME=texlive-custom:latest

main() {
    local extra=()

    set_log_depth 0

    if [[ "$use_docker" == true ]]; then build_if_not_exists $IMAGE_NAME "$SCRIPT_DIR/latex/texlive"; fi
    if [[ "$clean" == true ]]; then remove_aux_files && exit; fi
    if [[ "$autocompile" == true ]]; then extra+=(-pvc); fi

    latexmk_compile "$MAIN_FILE_NAME" "$@" "${extra[@]}"
}

_setConfigArgs() {
    ## Options
    while [ "${1:-}" != '' ]; do
        case "$1" in
        '-a' | '--autocompile')
            autocompile=true
            shift
            ;;
        '-c' | '--clean')
            clean=true
            shift
            ;;
        '--docker')
            use_docker=true
            shift
            ;;
        '--no-docker')
            use_docker=false
            shift
            ;;

        ## doesn't start with "-" it's the end of Options
        [!-]*)
            break
            ;;
        ## start with "-", but we don't know this particular option. Should we not exit with error??
        *)
            log_warn "Unknown option \"$1\", ignoring" 0
            ;;
        esac
        shift
    done

    if [ -z "$use_docker" ]; then
        if command_exists latexmk; then
            use_docker=false
        else
            use_docker=true
        fi
    fi

    ## Positional
    if [ "${1:-}" != '' ]; then MAIN_TEX=$1; fi

    MAIN_TEX=${MAIN_TEX:-"$PROJECT_ROOT/main.tex"}
    MAIN_FILE_NAME=$(basename "$MAIN_TEX")
    MAIN_DIR=$(realpath "$(dirname "$MAIN_TEX")")
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

run_docker() { docker run --rm -v "$MAIN_DIR:/data" -w /data $IMAGE_NAME "$@"; }

build_if_not_exists() {
    enter_new_func "Building $1"
    local DEPTH="$NEXT_LOG_DEPTH"

    if [[ "$(docker images -q "$1" 2>/dev/null)" == "" ]]; then
        log_info "Image $1 does not exist. Building..." "$DEPTH"
        docker build --force-rm --tag "$1" "$2"
    else
        log_info "Image $1 already exists. Skipping build." "$DEPTH"
    fi

    log_info "Done." "$DEPTH"
}

remove_aux_files() {
    enter_new_func "Removing auxiliary files"
    local DEPTH="$NEXT_LOG_DEPTH"

    run latexmk -aux-directory=.tmp -c;

    log_info "Done." "$DEPTH"
}

run() {
    if [[ "$use_docker" == true ]]; then
        run_docker "$@" && return;
    fi

    (cd "$MAIN_DIR" && "$@") && return
}

latexmk_compile() {
    enter_new_func "Compiling $1"
    local DEPTH="$NEXT_LOG_DEPTH"

    run latexmk -aux-directory=.tmp -pdflua "${@:2}" "$1"

    log_info "Done." "$DEPTH"
}


SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")") && source "$SCRIPT_DIR/util.bash"
_setConfigArgs "$@"
main "$@"