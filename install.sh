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
  script_name="${script_path##*/}"
  cmd_name="${script_name%.sh}"

  install --compare --verbose \
    "${script_path}" "${install_dir}/${cmd_name}"
}

# Usage ensure_install_dir_on_PATH
# Ensure that the installation directory is on the ${PATH}
ensure_install_dir_on_PATH() {

if ! which atb-init > /dev/null 2>&1; then
cat >> "${HOME}/.bashrc" <<-_EOF_

# Add Ansible Toolbox scripts to the PATH
export PATH=\${PATH}:${install_dir}
_EOF_
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

ensure_install_dir_on_PATH
