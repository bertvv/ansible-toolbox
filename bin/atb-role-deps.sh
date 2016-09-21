#! /usr/bin/bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Install role dependencies. This script is meant to be used in the context of
# ansible-skeleton[1] and ansible-role-skeleton[2].
#
# This script will search ansible/site.yml (or the specified playbook) for
# roles assigned to hosts in the form "user.role". It will then try to install
# them all. If possible, it will use Ansible Galaxy (on Linux, MacOS), but if
# this is not available (e.g. on Windows), it will use Git to clone the latest
# revision.
#
# Remark that this is a very crude technique and especially the Git fallback
# is very brittle. It will download HEAD, and not necessarily the latest
# release of the role. Additionally, the name of the repository is guessed,
# but if it does not exist, the script will fail.
#
# Using ansible-galaxy and a dependencies.yml file is the best method, but
# unavailable on Windows. This script is an effort to have a working
# alternative.
#
# [1] https://github.com/bertvv/ansible-skeleton
# [2] https://github.com/bertvv/ansible-role-skeleton

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don’t hide errors within pipes

#{{{ Variables
readonly SCRIPT_NAME=$(basename "${0}")

playbook=ansible/site.yml
roles_path=ansible/roles
#}}}

main() {
  local dependencies

  process_args "${@}"

  set_roles_path
  select_installer

  dependencies="$(find_dependencies)"

  for dep in ${dependencies}; do
    owner=${dep%%.*}
    role=${dep##*.}

    if [[ ! -d "${roles_path}/${dep}" ]]; then
      ${installer} "${owner}" "${role}"
    else
      echo "+ Skipping ${dep}, seems to be installed already"
    fi
  done
}

#{{{ Helper functions

# If the default roles path does not exist, try "roles/"
set_roles_path() {
  if [ ! -d "${roles_path}" ]; then
    roles_path="roles"
  fi
}

# Find dependencies in the specified playbook
find_dependencies() {
  grep '    - .*\..*' "${playbook}" \
    | cut --characters=7- \
    | sort --unique
}

# Check if command line arguments are valid
process_args() {
  if [ "${#}" -gt "1" ]; then
    echo "Expected at most 1 argument, got ${#}" >&2
    usage
    exit 2
  elif [ "${#}" -eq "1" ]; then
    if [ "${1}" = '-h' -o "${1}" = '--help' ]; then
      usage
      exit 0
    elif [ ! -f "${1}" ]; then
      echo "Playbook ‘${1}’ not found." >&2
      usage
      exit 1
    else
      playbook="${1}"
    fi
  elif [ "${#}" -eq "0" -a ! -f "${playbook}" ]; then
    cat << _EOF_
Default playbook ${playbook} not found. Maybe you should cd to the
directory above ${playbook%%/*}/, or specify the playbook.
_EOF_
    usage
    exit 1
  fi
}

# Print usage message on stdout
usage() {
cat << _EOF_
Usage: ${SCRIPT_NAME} [PLAYBOOK]

  Installs role dependencies found in the specified playbook (or ${playbook}
  if none was given).

OPTIONS:

  -h, --help  Prints this help message and exits

EXAMPLES:

$ ${SCRIPT_NAME}
$ ${SCRIPT_NAME} test.yml
_EOF_
}


# Usage: select_installer
# Sets the variable `installer`, the function to use when installing roles
# Try to use ansible-galaxy when it is available, and fall back to `git clone`
# when it is not.
select_installer() {
  if which ansible-galaxy > /dev/null 2>&1 ; then
    installer=install_role_galaxy
  else
    installer=install_role_git
  fi
}

# Usage: is_valid_url URL
# returns 0 if the URL is valid, 22 otherwise
is_valid_url() {
  local url=$1

  curl --silent --fail "${url}" > /dev/null
}

# Usage: install_role_galaxy OWNER ROLE
install_role_galaxy() {
  local owner=$1
  local role=$2
  ansible-galaxy install --roles-path="${roles_path}" \
    "${owner}.${role}"
}

# Usage: install_role_git OWNER ROLE
install_role_git() {
  local owner=$1
  local role=$2

  # First try https://github.com/OWNER/ansible-role-ROLE
  local repo="https://github.com/${owner}/ansible-role-${role}"

  if is_valid_url "${repo}"; then
    git clone "${repo}" "${roles_path}/${owner}.${role}"
  else
  # If that fails, try https://github.com/OWNER/ansible-ROLE
    git clone "https://github.com/${owner}/ansible-${role}" \
      "${roles_path}/${owner}.${role}"
  fi
}
#}}}

main "${@}"
