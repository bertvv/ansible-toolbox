#! /usr/bin/bash
#
# Author:   Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Run Ansible manually on a host managed by Vagrant. Fix the path to the Vagrant
# private key before use!

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

#{{{ Variables
inventory_file=".vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory"
ssh_user=vagrant
private_key_path="${HOME}/.vagrant.d/insecure_private_key"
#}}}
#{{{  Functions

usage() {
cat << _EOF_
Usage: ${0} [PLAYBOOK] [ARGS]
Runs Ansible-playbook manually on a host controlled by Vagrant. Run this script
from the same directory as the Vagrantfile.

  PLAYBOOK  the playbook to be run (default: ansible/site.yml)
  ARGS      other options that are passed on to ‘ansible-playbook’ verbatim
_EOF_
}

find_private_key() {
  local vagrant_key
  local num_keys_found

  vagrant_key=$(ls .vagrant/machines/*/virtualbox/private_key)
  num_keys_found=$(echo "${vagrant_key}" | wc --lines)

  if [ "${num_keys_found}" -gt "1" ]; then
    cat >&2 << _EOF_
I found multiple private keys in the current Vagrant environment. Sorry,
I can't handle that (yet?).
_EOF_
    exit 2
  fi

  private_key_path="${vagrant_key}"
}

#}}}
#  {{{ Command line parsing

if [ "${#}" -gt "0" -a -f "${1}" ]; then
  playbook="${1}"
  shift
else
  playbook="ansible/site.yml"
fi


# }}}
# Script proper

# Ignore SSH host key checking (it would create an entry in ~/.ssh/known_hosts
# and fail when you create a new VM.
export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook \
  "${playbook}" \
  --inventory="${inventory_file}" \
  --connection=ssh \
  --user="${ssh_user}" \
  --private-key="${private_key_path}" \
  "$@"

