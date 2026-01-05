#!/usr/bin/env bash

# This script sets up a small Android-style environment for lv_port_linux.
# Source it (". ./envsetup.sh") to gain helper commands such as lunch/m/h.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "envsetup.sh must be sourced, e.g. 'source envsetup.sh'" >&2
    exit 1
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "envsetup.sh requires bash." >&2
    return 1
fi

if [[ -z "${_LVGL_ENV_INITIALIZED:-}" ]]; then
    export LVGL_PORT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export _LVGL_ORIG_CC="${CC:-}"
    export _LVGL_ORIG_CXX="${CXX:-}"
    export _LVGL_ORIG_PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR:-}"
    export _LVGL_ORIG_PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:-}"
    export _LVGL_ENV_INITIALIZED=1
    export LVGL_BUILD_BASE_DIR="${LVGL_BUILD_BASE_DIR:-${LVGL_PORT_ROOT}/build}"
fi

_lvgl_detect_jobs() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN
    else
        printf '4'
    fi
}

export LVGL_MAKE_JOBS="${LVGL_MAKE_JOBS:-$(_lvgl_detect_jobs)}"

declare -a _LVGL_LUNCH_MENU=("host-sdl" "host-wayland" "rk3568-drm")
declare -A _LVGL_LUNCH_DESC=(
    ["host-sdl"]="Native SDL simulator on the host (gcc/g++)"
    ["host-wayland"]="Native Wayland client on the host"
    ["rk3568-drm"]="RK3568 target using DRM/KMS with a cross toolchain"
)
declare -A _LVGL_LUNCH_DEFAULTS=(
    ["host-sdl"]="$LVGL_PORT_ROOT/configs/lunch/host_sdl.defaults"
    ["host-wayland"]="$LVGL_PORT_ROOT/configs/lunch/host_wayland.defaults"
    ["rk3568-drm"]="$LVGL_PORT_ROOT/configs/lunch/rk3568_drm.defaults"
)

_lvgl_print_lunch_menu() {
    echo "Available lunch combos:"
    local idx=1
    for entry in "${_LVGL_LUNCH_MENU[@]}"; do
        printf "  %d. %s - %s\n" "${idx}" "${entry}" "${_LVGL_LUNCH_DESC[$entry]}"
        ((idx++))
    done
    if [[ -n "${LVGL_LUNCH_TARGET:-}" ]]; then
        echo "Current selection: ${LVGL_LUNCH_TARGET}"
    else
        echo "Current selection: (none)"
    fi
}

_lvgl_reset_toolchain() {
    if [[ -n "${_LVGL_ORIG_CC:-}" ]]; then
        export CC="${_LVGL_ORIG_CC}"
    else
        unset CC
    fi

    if [[ -n "${_LVGL_ORIG_CXX:-}" ]]; then
        export CXX="${_LVGL_ORIG_CXX}"
    else
        unset CXX
    fi

    if [[ -n "${_LVGL_ORIG_PKG_CONFIG_SYSROOT_DIR:-}" ]]; then
        export PKG_CONFIG_SYSROOT_DIR="${_LVGL_ORIG_PKG_CONFIG_SYSROOT_DIR}"
    else
        unset PKG_CONFIG_SYSROOT_DIR
    fi

    if [[ -n "${_LVGL_ORIG_PKG_CONFIG_LIBDIR:-}" ]]; then
        export PKG_CONFIG_LIBDIR="${_LVGL_ORIG_PKG_CONFIG_LIBDIR}"
    else
        unset PKG_CONFIG_LIBDIR
    fi
}

_lvgl_generate_lv_conf() {
    local defaults_file="$1"
    if [[ -z "${defaults_file}" || ! -f "${defaults_file}" ]]; then
        echo "No lv_conf defaults found for this target, skipping lv_conf.h update."
        return 0
    fi

    (cd "${LVGL_PORT_ROOT}" && python3 lvgl/scripts/generate_lv_conf.py \
        --template lvgl/lv_conf_template.h \
        --defaults "${defaults_file}" \
        --config lv_conf.h) || {
        echo "Failed to regenerate lv_conf.h from ${defaults_file}" >&2
        return 1
    }
}

_lvgl_apply_lunch_target() {
    local target="$1"
    case "${target}" in
        host-sdl)
            local host_cc="${LVGL_HOST_CC:-${_LVGL_ORIG_CC:-gcc}}"
            local host_cxx="${LVGL_HOST_CXX:-${_LVGL_ORIG_CXX:-g++}}"
            export CC="${host_cc}"
            export CXX="${host_cxx}"
            unset PKG_CONFIG_SYSROOT_DIR
            unset PKG_CONFIG_LIBDIR
            export LVGL_LUNCH_BACKENDS="sdl"
            ;;
        host-wayland)
            local host_cc="${LVGL_HOST_CC:-${_LVGL_ORIG_CC:-gcc}}"
            local host_cxx="${LVGL_HOST_CXX:-${_LVGL_ORIG_CXX:-g++}}"
            export CC="${host_cc}"
            export CXX="${host_cxx}"
            unset PKG_CONFIG_SYSROOT_DIR
            unset PKG_CONFIG_LIBDIR
            export LVGL_LUNCH_BACKENDS="wayland"
            ;;
        rk3568-drm)
            local prefix="${RK3568_TOOLCHAIN_PREFIX:-aarch64-linux-gnu}"
            [[ "${prefix}" == *- ]] || prefix="${prefix}-"
            local rk_cc="${RK3568_CC:-${prefix}gcc}"
            local rk_cxx="${RK3568_CXX:-${prefix}g++}"
            export CC="${rk_cc}"
            export CXX="${rk_cxx}"
            if [[ -n "${RK3568_SYSROOT:-}" ]]; then
                export PKG_CONFIG_SYSROOT_DIR="${RK3568_SYSROOT}"
                export PKG_CONFIG_LIBDIR="${RK3568_SYSROOT}/usr/lib/pkgconfig:${RK3568_SYSROOT}/usr/share/pkgconfig"
            else
                echo "Warning: RK3568_SYSROOT is not set; pkg-config may resolve host libraries." >&2
                unset PKG_CONFIG_SYSROOT_DIR
                unset PKG_CONFIG_LIBDIR
            fi
            export LVGL_LUNCH_BACKENDS="drm"
            ;;
        *)
            echo "Unknown lunch target '${target}'" >&2
            return 1
            ;;
    esac

    return 0
}

_lvgl_configure_cmake() {
    local target="$1"
    if ! command -v cmake >/dev/null 2>&1; then
        echo "cmake is not installed or not in PATH." >&2
        return 1
    fi

    local base_dir="${LVGL_BUILD_BASE_DIR:-${LVGL_PORT_ROOT}/build}"
    local build_dir="${base_dir}/${target}"
    mkdir -p "${build_dir}"

    local -a cmake_args=(-S "${LVGL_PORT_ROOT}" -B "${build_dir}")
    if [[ "${target}" == "rk3568-drm" ]]; then
        local toolchain_file="${RK3568_CMAKE_TOOLCHAIN_FILE:-${LVGL_PORT_ROOT}/user_cross_compile_setup.cmake}"
        if [[ -f "${toolchain_file}" ]]; then
            cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="${toolchain_file}")
        else
            echo "Warning: RK3568 toolchain file not found at ${toolchain_file}" >&2
        fi
    fi

    if [[ -n "${LVGL_EXTRA_CMAKE_ARGS:-}" ]]; then
        # shellcheck disable=SC2206
        local extra_args=(${LVGL_EXTRA_CMAKE_ARGS})
        cmake_args+=("${extra_args[@]}")
    fi

    echo "Configuring CMake build dir: ${build_dir}"
    if ! (cd "${LVGL_PORT_ROOT}" && cmake "${cmake_args[@]}"); then
        echo "CMake configuration failed." >&2
        return 1
    fi

    export LVGL_BUILD_DIR="${build_dir}"
    return 0
}

lunch() {
    local selection="$1"
    if [[ "${selection}" == "-c" || "${selection}" == "clear" ]]; then
        _lvgl_reset_toolchain
        unset LVGL_LUNCH_TARGET
        unset LVGL_LUNCH_DESCRIPTION
        unset LVGL_LUNCH_BACKENDS
        unset LVGL_BUILD_DIR
        echo "Lunch target cleared."
        return 0
    fi

    if [[ "${selection}" == "-l" || "${selection}" == "list" ]]; then
        _lvgl_print_lunch_menu
        return 0
    fi

    if [[ -z "${selection}" ]]; then
        _lvgl_print_lunch_menu
        read -rp "Select a target: " selection
    fi

    if [[ "${selection}" =~ ^[0-9]+$ ]]; then
        local idx=$((selection - 1))
        if ((idx < 0 || idx >= ${#_LVGL_LUNCH_MENU[@]})); then
            echo "Invalid selection '${selection}'" >&2
            return 1
        fi
        selection="${_LVGL_LUNCH_MENU[$idx]}"
    fi

    if [[ -z "${_LVGL_LUNCH_DESC[$selection]+_}" ]]; then
        echo "Unknown lunch target '${selection}'" >&2
        return 1
    fi

    if ! _lvgl_generate_lv_conf "${_LVGL_LUNCH_DEFAULTS[$selection]}"; then
        return 1
    fi

    if ! _lvgl_apply_lunch_target "${selection}"; then
        return 1
    fi

    if ! _lvgl_configure_cmake "${selection}"; then
        return 1
    fi

    export LVGL_LUNCH_TARGET="${selection}"
    export LVGL_LUNCH_DESCRIPTION="${_LVGL_LUNCH_DESC[$selection]}"

    echo "Lunch target: ${LVGL_LUNCH_TARGET} (${LVGL_LUNCH_DESCRIPTION})"
    echo "  CC=${CC}"
    echo "  CXX=${CXX}"
    if [[ -n "${PKG_CONFIG_SYSROOT_DIR:-}" ]]; then
        echo "  PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR}"
    fi
    echo "  Enabled backends: ${LVGL_LUNCH_BACKENDS}"
    echo "  Build directory: ${LVGL_BUILD_DIR}"
    echo "lv_conf.h regenerated from ${_LVGL_LUNCH_DEFAULTS[$selection]}"
}

croot() {
    cd "${LVGL_PORT_ROOT}" || return
}

m() {
    if [[ -z "${LVGL_BUILD_DIR:-}" ]]; then
        echo "No build directory configured. Run 'lunch <target>' first." >&2
        return 1
    fi
    (cd "${LVGL_PORT_ROOT}" && cmake --build "${LVGL_BUILD_DIR}" --parallel "${LVGL_MAKE_JOBS}" "$@")
}

mclean() {
    if [[ -z "${LVGL_BUILD_DIR:-}" ]]; then
        echo "No build directory configured. Run 'lunch <target>' first." >&2
        return 1
    fi
    (cd "${LVGL_PORT_ROOT}" && cmake --build "${LVGL_BUILD_DIR}" --target clean "$@")
}

h() {
    cat <<EOF
Helper commands (source envsetup.sh first):
  lunch [target|number]   - Select a build preset. Runs CMake configure automatically.
  croot                   - cd into ${LVGL_PORT_ROOT}
  m [cmake args]          - Run 'cmake --build ${LVGL_BUILD_DIR:-<selected>}' with --parallel ${LVGL_MAKE_JOBS}
  mclean                  - Run 'cmake --build ... --target clean'
  h                       - Print this help

Environment after lunch:
  LVGL_LUNCH_TARGET       - Name of the active preset
  CC/CXX                  - Toolchains that 'make' will use
  PKG_CONFIG_*            - Overridden for cross builds when RK3568_SYSROOT is set
  LVGL_LUNCH_BACKENDS     - Hint of which LVGL backends are enabled via lv_conf defaults
  LVGL_BUILD_DIR          - Target-specific CMake build directory

Add new presets by creating configs/lunch/<name>.defaults and extending _LVGL_LUNCH_MENU.
EOF
}

echo "Loaded lv_port_linux env helpers. Run 'h' for available commands."
