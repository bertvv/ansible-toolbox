#! /usr/bin/bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Installation script for https://github.com/bertvv/ansible-toolbox

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

#{{{ Functions

usage() {
cat << _EOF_
Usage: ${0} [OPTIONS] [INSTALL_DIR]

  Installs the scripts into INSTALL_DIR. If the installation
  directory was not specified, install into /usr/local/bin
  when invoked by the superuser, or else into ~/bin.

Options:

  -h, --help  Print this message and exit
_EOF_
}

# Usage: validate_install_dir DIR
# Ensures the installation directory exists
validate_install_dir() {
  local dir="${1}"

  if [ ! -d "${dir}" ]; then
    echo "Installation directory ‘${dir}’ doesn't exist"
    echo "Create it or specify an existing directory"
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

  install -C -v \
    "${script_path}" "${install_dir}/${cmd_name}"
}

# Usage: update_path_in_bashrc
# Adds the installation directory to the end of ~/.bashrc
update_path_in_bashrc() {
cat >> "${HOME}/.bashrc" <<-_EOF_

# Add Ansible Toolbox scripts to the PATH
export PATH=\${PATH}:${install_dir}
_EOF_
}

# Usage ensure_scripts_on_PATH
# Check whether the installed scripts are on the ${PATH} and if not, add
# installation directory to ~/.bashrc if possible
ensure_scripts_on_PATH() {

  if ! which atb-init > /dev/null 2>&1; then
    if [ -f "${HOME}/.bashrc" ]; then
      update_path_in_bashrc
    else
      echo "Warning: the installation directory is not in the PATH"
    fi
  fi
}

#}}}
#{{{ Variables

# Default installation directory
if [ "${UID}" -eq "0" ]; then
  install_dir="/usr/local/bin"
else
  install_dir="${HOME}/bin"
fi

src_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/bin"
#}}}
#{{{ Command line parsing

if [ "$#" -gt "0" ]; then
  if [ "$1" = "-h" -o "$1" = "--help" ]; then
    usage
    exit 0
  else
    install_dir="$1"
  fi
fi

#}}}
# Script proper

validate_install_dir "${install_dir}"

for script in "${src_dir}"/*; do
  install_script "${script}"
done

ensure_scripts_on_PATH
