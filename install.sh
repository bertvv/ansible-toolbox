#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Installation script for https://github.com/bertvv/ansible-toolbox

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

#{{{ Variables

# Color definitions
readonly reset='\e[0m'
readonly cyan='\e[0;36m'
readonly red='\e[0;31m'
readonly yellow='\e[0;33m'

# Default installation directory
if [ "${UID}" -eq "0" ]; then
  install_dir="/usr/local/bin"
else
  install_dir="${HOME}/.local/bin"
fi

src_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/bin"
#}}}
#{{{ Functions

usage() {
cat << _EOF_
Usage: ${0} [OPTIONS] [INSTALL_DIR]

  Installs the scripts into INSTALL_DIR. If the installation
  directory was not specified, install into /usr/local/bin
  when invoked by the superuser, or else into ~/.local/bin.

Options:

  -h, --help  Print this message and exit
_EOF_
}

# Usage: validate_install_dir DIR
# Checks whether the installation directory exists
validate_install_dir() {
  local dir="${1}"
  debug "Checking whether installation dir ${dir} exists"

  if [ ! -d "${dir}" ]; then
    error "Installation directory ‘${dir}’ doesn't exist"
    error "Create it or specify an existing directory"
    usage
    exit 1
  fi
}

# Usage install_script PATH
# Installs the script, specified by its full pathname to the
# installation directory.
install_script() {
  local script_path="${1}"

  # strip path and extension
  local script_name="${script_path##*/}"
  local cmd_name="${script_name%.sh}"

  #debug "Installing ${script_name} to ${cmd_name}"

  install --compare --verbose \
    "${script_path}" "${install_dir}/${cmd_name}"
}

# Usage: update_path_in_bashrc
# Adds the installation directory to the end of ~/.bashrc
update_path_in_bashrc() {
  info "Adding installation directory to ~/.bashrc"
cat >> "${HOME}/.bashrc" <<-_EOF_

# Add Ansible Toolbox scripts to the PATH
export PATH=\${PATH}:${install_dir}
_EOF_
}

# Usage ensure_scripts_on_PATH
# Check whether the installed scripts are on the ${PATH} and if not, add
# installation directory to ~/.bashrc if possible
ensure_scripts_on_path() {

  if ! which atb-init > /dev/null 2>&1; then
    if [ -f "${HOME}/.bashrc" ]; then
      update_path_in_bashrc
    else
      info "Warning: the installation directory is not in the PATH"
    fi
  fi
}

# Usage: info [ARG]...
#
# Prints all arguments on the standard output stream
info() {
  printf "${yellow}>>> %s${reset}\n" "${*}"
}

# Usage: debug [ARG]...
#
# Prints all arguments on the standard output stream
debug() {
  printf "${cyan}### %s${reset}\n" "${*}"
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf "${red}!!! %s${reset}\n" "${*}" 1>&2
}

#}}}
#{{{ Command line parsing

if [ "$#" -gt "0" ]; then
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
  else
    install_dir="$1"
  fi
fi

#}}}
# Script proper

validate_install_dir "${install_dir}"

debug "Installing scripts: ${src_dir}/*.sh"
for script in ${src_dir}/*.sh; do
  install_script "${script}"
done

ensure_scripts_on_path
