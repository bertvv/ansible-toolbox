#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: atb-init PROJECT_NAME [ROLE]...
#/        atb-init -h|--help
#/
#/ Initialises a Vagrant + Ansible project based and, optionally, installs
#/ the specified roles from Ansible Galaxy. The project skeleton code is
#/ downloaded from https://github.com/bertvv/ansible-skeleton
#/ 
#/ OPTIONS
#/   -h, --help
#/                Print this help message
#/
#/ EXAMPLES
#/  atb-init sandbox
#/  atb-init lampstack bertvv.mariadb bertvv.httpd
#
# Dependencies:
# - ansible-galaxy
# - git
# - unzip
# - wget

#{{{ Bash settings
set -o errexit    # abort on nonzero exitstatus
set -o nounset    # abort on unbound variable
set -o pipefail   # don't hide errors within pipes
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
# Debug info ('on' to enable)
readonly debug='on'

# Download location of skeleton code
readonly download_url='https://github.com/bertvv/ansible-skeleton/archive'
readonly skeleton_code_archive='ansible-skeleton-master.zip'
#}}}

main() {
  check_cli_options "${@}"
  initialize_project_dir "${1}"
  shift
  install_roles "${@}"
}

#{{{ Helper functions

check_cli_options() {
  if [ "$#" -eq '0' ]; then
    error "Expected at least 1 argument"
    usage
    exit 2
  elif [ "${1}" = '-h' ] || [ "${1}" = '--help' ]; then
    usage
    exit 0
  fi
}

# Usage: initialize_project_dir DIRECTORY
#
# Initialize a project directory from skeleton code
initialize_project_dir() {
  local project="${1}"

  if [ -d "${project}" ]; then
    error "Project directory ${project} already exists. Bailing out."
    exit 1
  fi

  log "Downloading skeleton code"
  wget "${download_url}/master.zip"
  unzip "${skeleton_code_archive}"
  rm "${skeleton_code_archive}"
  mv ansible-skeleton-master "${project}"

  log "Initializing Git repository"
  cd "${project}"
  git init
  git add .
  git commit --message "Initial commit from Ansible skeleton"
  mkdir ansible/host_vars/
}

# Usage: install_roles [ROLE_NAME]...
#
# Iterate over the specified roles (if any) and call the install function for
# each
install_roles() {
  for role in "${@}"; do
    install_role "${role}"
  done
}

# Usage: install_role ROLE_NAME
#
# Install the specified role from Ansible Galaxy, or, failing that, from
# Github.
install_role() {
  local role_name="${1}"

  log "Installing ${role_name} from Ansible Galaxy"
  if ! ansible-galaxy install -p ansible/roles "${role_name}"; then

    log "This role does not seem to be on Ansible Galaxy."
    local user=${1%%\.*}
    local role=${1##*\.}
    local git_url="https://github.com/${user}/ansible-role-${role}.git"

    log "Trying to clone role from ${git_url}"
    if ! git clone "${git_url}" "ansible/roles/${role_name}"; then

      log "This does not seem to be an existing Github repo"
      local git_url="https://github.com/${user}/ansible-${role}.git"

      log "Trying to clone role from ${git_url}"
      if ! git clone "${git_url}" "ansible/roles/${role_name}"; then
        log "Cloning failed, skipping this role"
      fi
    fi
  fi
}

# Print usage message on stdout by parsing start of script comments
usage() {
  grep '^#/' "${script_dir}/${script_name}" | sed 's/^#\/\w*//'
}

# Usage: log [ARG]...
#
# Prints all arguments on the standard output stream
log() {
  printf "${yellow}>>> %s${reset}\\n" "${*}"
}

# Usage: debug [ARG]...
#
# Prints all arguments on the standard output stream,
# if debug output is enabled
debug() {
  [ "${debug}" != 'on' ] || printf "${cyan}### %s${reset}\\n" "${*}"
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf "${red}!!! %s${reset}\\n" "${*}" 1>&2
}

#}}}

main "${@}"

