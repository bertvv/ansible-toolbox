#! /usr/bin/bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Retrieves Ansible variables from the specified host (assumed to be a
# Vagrant VM).
#
# See usage() for details.

#{{{ Bash settings
# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail
#}}}
#{{{ Variables
readonly SCRIPT_NAME=$(basename "${0}")
readonly SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)

# Colours
readonly YELLOW='\e[0;33m'
readonly BLUE='\e[0;34m'
readonly RESET='\e[0m'

# Inventory file
readonly INVENTORY="${PWD}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory"
#}}}

main() {
  check_if_inventory_exists

  hosts=$(determine_target_hosts "${@}")

  for host in ${hosts}; do
    get_facts "${host}"
  done
}

#{{{ Helper functions

check_if_inventory_exists() {
  if [ ! -f "${INVENTORY}" ]; then
    cat >&2 << _EOF_
Vagrant inventory file not found. Execute this command from a directory
containing a Vagrantfile.
_EOF_
    usage
    exit 1
  fi
}

determine_target_hosts() {
  if [ "${#}" -ne "0" ]; then
    echo "${@}"
  else
    enumerate_vagrant_hosts
  fi
}

enumerate_vagrant_hosts() {
  vagrant status \
    | tail -n +3 \
    | head -n -4 \
    | cut -d' ' -f1
}

# Print usage message on stdout
usage() {
cat << _EOF_
Usage: ${SCRIPT_NAME} HOST...

  Retrieves Ansible variables/facts from the specified hosts (assumed to be
  Vagrant VMs

EXAMPLES:

  ${SCRIPT_NAME} box1 box2
_EOF_
}

# Usage: get_facts HOST
get_facts() {
  local host="${1}"
  echo -e "${YELLOW}Ansible variables/facts for host ${BLUE}${host}${RESET}"

  ansible "${host}" \
    --module-name=setup \
    --inventory-file="${INVENTORY}"
}

#}}}

main "${@}"

