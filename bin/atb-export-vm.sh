#! /usr/bin/env bash
#
# Author:   Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: atb-export-vm VM_NAME
#/
#/   with VM_NAME the name of a VirtualBox VM.
#/
#/ Exports a VirtualBox VM to an OVA file, removing the "/vagrant" shared 
#/ folder, if it exists.

#{{{ Bash settings
# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
#}}}

#{{{ Variables
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)

# Color definitions
readonly reset='\e[0m'
readonly cyan='\e[0;36m'
readonly red='\e[0;31m'
readonly yellow='\e[0;33m'

readonly today=$(date --iso-8601)
#}}}

main() {
  check_args "${@}"

  local vm="${1}"

  if ! is_a_vm "${vm}"; then
    error "${vm} is not a VM."
    list_available_vms
    exit 1
  fi

  if is_vm_running "${vm}"; then
    error "${vm} is still running, shut it down first!"
    exit 1
  fi

  delete_shared_folders "${vm}"

  readonly local ova=$(unique_ova_name "${vm}")
  info "Exporting to file: ${ova}"
  vboxmanage export "${vm}" --output "${ova}" --options manifest
}


#{{{ Helper functions

# Check if command line arguments are valid
check_args() {
  if [ "${#}" -ne "1" ]; then
    error "Expected 1 argument, got ${#}"
    usage
    exit 2
  fi
  if [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
    usage
    exit 0
  fi
}

# Print usage message on stdout by parsing start of script comments
usage() {
  local help_msg
  help_msg=$(grep '^#/' "${script_dir}/${script_name}" | sed 's/^#\/\s\{,1\}//')
  echo "${help_msg}"

  list_available_vms
}

list_available_vms() {
  info "Available VMs"
  vboxmanage list vms
}

# Usage: is_a_vm VM
# Predicate that checks whether the specified VM exists in VirtualBox
is_a_vm() {
  local vm="${1}"
  vboxmanage list vms | grep --quiet "${vm}"
}

# Usage: is_vm_running VM
# Predicate that checks whether the specified VM is running
is_vm_running() {
  local vm="${1}"
  vboxmanage showvminfo "${vm}" | grep --quiet "running (since"
}

# Usage: list_shared_folders VM
# Lists shared folders of the specified VM
list_shared_folders() {
  local vm="${1}"

  vboxmanage showvminfo "${vm}" \
    | grep '^Name:.*Host path:' \
    | awk '{print $2}' \
    | tr -d "',"
}

# Usage: delete_shared_folders VM
# Deletes any shared folders the specified VM has
delete_shared_folders() {
  info "Removing shares (if any)"
  local vm="${1}"
  local shares
  shares=$(list_shared_folders "${vm}")

  for share in ${shares}; do
    info "share ${share}"
    vboxmanage sharedfolder remove "${vm}" --name "${share}"
  done
}

# Usage: unique_ova_name VM
# Generates a unique name for the .ova file
# The default format is VMNAME-YYYY-MM-DD.ova, if that name already exists, the
# format is VMNAME-YYYY-MM-DD-N.ova, with N = 1, 2, ...
unique_ova_name() {
  local vm="${1}"
  local base_name="${vm}-${today}"

  if [ ! -f "${base_name}.ova" ]; then
    echo "${base_name}"
  else
    local num=1
    while [ -f "${base_name}-${num}.ova" ]; do
      ((num++))
    done
    echo "${base_name}-${num}.ova"
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
# {{{ Command line parsing

#}}}

main "${@}"
