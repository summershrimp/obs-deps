autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='openssl'
local version='1.1.1s'
local url='https://www.openssl.org/source/openssl-1.1.1s.tar.gz'
local hash="${0:a:h}/checksums/openssl-1.1.1s.tar.gz.sha256"
local patches=()

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd "${dir}"

  if [[ ${clean_build} -gt 0 && -f "build_${arch}/Makefile" ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf "build_${arch}"
  }
}

config() {
  autoload -Uz mkcd progress

  case ${target} {
    macos-universal)
      autoload -Uz universal_config && universal_config
      return
      ;;
    macos-*)
      args+=("darwin64-${arch}-cc")
      ;;
  }

  log_info "Config (%F{3}${target}%f)"
  cd "${dir}"

  if [[ shared_libs -gt 0 ]] {
    args+=(
      "-shared"
    )
  }
  args+=(
    --prefix="${target_config[output_dir]}"
  )

  mkcd "build_${arch}"

  log_debug "Configure args: ${args}"
  CFLAGS="${c_flags}" \
  LDFLAGS="${ld_flags}" \
  PKG_CONFIG_PATH="${target_config[output_dir]}/lib/pkgconfig" \
  PATH="${(j.:.)cc_path}" \
  progress ../Configure ${args}
}

build() {
  autoload -Uz mkcd progress

  case ${target} {
    macos-universal)
      autoload -Uz universal_build && universal_build
      return
      ;;
  }

  log_info "Build (%F{3}${target}%f)"

  cd "${dir}/build_${arch}"

  log_debug "Running 'make -j ${num_procs}'"
  PATH="${(j.:.)cc_path}" progress make -j "${num_procs}"
}

install() {
  autoload -Uz progress

  if [[ ! -d "${dir}/build_${arch}" ]] {
    log_warning "No binaries for architecture ${arch} found, skipping installation"
    return
  }

  log_info "Install (%F{3}${target}%f)"

  cd "${dir}/build_${arch}"

  PATH="${(j.:.)cc_path}" progress make install_sw

  if [[ "${config}" =~ "Release|MinSizeRel" && ${shared_libs} -eq 1 ]] {
    case ${target} {
      macos-*)
        local file
        for file ("${target_config[output_dir]}"/lib/libssl*.dylib "${target_config[output_dir]}"/lib/libcrypto*.dylib) {
          if [[ ! -e "${file}" || -h "${file}" ]] continue
          strip -x "${file}"
          log_status "Stripped ${file#"${target_config[output_dir]}"}"
        }
        ;;
    }
  }
}

fixup() {
  autoload -Uz fix_rpaths

  cd "${dir}"

  case ${target} {
    macos*)
      if (( shared_libs )) {
        log_info "Fixup (%F{3}${target}%f)"
        fix_rpaths "${target_config[output_dir]}"/lib/libssl*.dylib
        fix_rpaths "${target_config[output_dir]}"/lib/libcrypto*.dylib
      }
      ;;
  }
}
