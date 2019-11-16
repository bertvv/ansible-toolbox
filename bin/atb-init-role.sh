#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: atb-init-role [OPTIONS]... ROLE
#/
#/ Generates scaffolding code for an Ansible role based on
#/ https://github.com/bertvv/ansible-role-skeleton.
#/
#/ A git repo is initialized and the initial code is committed.
#/
#/ OPTIONS
#/   -h, --help
#/                Print this help message and exit
#/
#/   -t, --tests=TESTENV...
#/                Initialize the specified test environment(s) for a new or
#/                existing role. Possible values: docker,vagrant
#/                Warning: no spaces are allowed in this option!
#/
#/ EXAMPLES
#/  atb-init-role prometheus
#/  atb-init-role -t=vagrant hosts
#/  atb-init-role --tests=docker zabbix
#/  atb-init-role --tests=docker,vagrant nginx

#{{{ Bash settings
set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes
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
# Debug log ('on' to enable)
readonly debug='on'

# Script configuration variables
readonly role_skeleton='https://github.com/bertvv/ansible-role-skeleton'
readonly skeleton_download_dir="$(mktemp --directory)"

test_env='none'  # which test environment(s) should be initialized
role_name=''
role_dir=''
#}}}

main() {
  process_parameters "${@}"
  init_role_dir
  setup_test_environments "${test_env}"
  cleanup
}

#{{{ process_parameters()
# Process command line parameters and set script configuration variables
process_parameters() {
  while [ "$#" -gt 0 ]; do
    case "${1}" in
      -h|--help)
        usage
        exit 0
        ;;
      -t=*|--tests=*)
        test_env="${1##*=}"
        debug "Test environment initialization requested: ${test_env}"
        shift
        ;;
      -*)
        error "Unknown option: ${1}"
        usage
        exit 2
        ;;
      *)
        role_name="${1}"
        break
        ;;
    esac
  done

  if [ x"${role_name}" = x'' ]; then
    error "No role name specified!"
    usage
    exit 2
  fi

  # Check if we're inside the role dir and move out of it if necessary
  local current_dir="${PWD##*/}"
  if [ "${current_dir}" = "${role_name}" ]; then
    cd ..
  fi
  role_dir="${PWD}/${role_name}"
  debug "Role directory: ${role_dir}"
}
#}}}
#{{{ init_role_dir()
# Usage: init_role_dir
#
# Initialize a directory with scaffolding code for the specified Ansible role.
# If the directory already exists, this function does nothing.
init_role_dir() {
  log "Initializing role directory ${role_dir}"

  # First check if the directory already exists
  if [ -d "${role_dir}" ]; then
    log "A directory with name ´${role_name}´ already exists. Skipping this step."
    return
  fi

  ensure_skeleton_code_is_downloaded

  log "Creating directory for the role: ${role_dir}"
  mkdir "${role_dir}"

  debug 'Copy the role skeleton code'
  rsync --archive --exclude '.git' "${skeleton_download_dir}/" "${role_dir}"


  debug "Setting year in the LICENSE file"
  sed --in-place --expression "s/YEAR/$(date +%Y)/" "${role_dir}/LICENSE.md"

  subst_role_name "${role_dir}"

  log "Initializing Git repository, first commit"
  pushd "${role_dir}" > /dev/null 2>&1
  git init --quiet
  git add .
  git commit --quiet --message "First commit from role skeleton"
  popd > /dev/null 2>&1
}
#}}}
#{{{ ensure_skeleton_code_is_downloaded() 
ensure_skeleton_code_is_downloaded() {

  if [ ! -d "${skeleton_download_dir}/.git" ]; then
    debug "Downloading skeleton code from Github"
    git clone --quiet "${role_skeleton}" "${skeleton_download_dir}"
  fi

}

#}}}
#{{{ setup_test_environments()
# Usage: setup_test_environments ENVIRONMENT...
#
# With ENVIRONMENT one of none, vagrant, or docker, or a comma-separated list
# of the desired test environments
setup_test_environments() {
  local environments

  # Split comma separated environment names into an array
  IFS=',' read -ra environments <<< "${1}"

  for environment in "${environments[@]}"; do
    debug "Setting up test env: ${environment}"
    case "${environment}" in
      'none')
        return
        ;;
      'vagrant')
        setup_vagrant_environment
        ;;
      'docker')
        setup_docker_environment
        ;;
      *)
        error "Test environment ${environment} is not defined, skipping"
        ;;
    esac
  done

}

#}}}
#{{{ setup_docker_environment()
# Usage: setup_docker_environment
setup_docker_environment() {
  fetch_test_branch 'docker'

  if [ ! -f "${role_dir}/.travis.yml" ]; then
    debug 'Adding .travis.yml'
    cd "${role_dir}"
    cp docker-tests/.travis.yml .
    git add .travis.yml
    git commit --quiet --message \
      'Add .travis.yml'
  fi
}

#}}}
#{{{ setup_vagrant_environment()
# Usage: setup_vagrant_environment
setup_vagrant_environment() {
  fetch_test_branch 'vagrant'

  debug 'Create subdirectory for roles used in the test playbook'
  if [ ! -d "${role_dir}/vagrant-tests/roles" ]; then
    debug 'Making role available in the test environment'
    pushd "${role_dir}/vagrant-tests/" > /dev/null 2>&1
    mkdir roles

    debug 'Link from roles/ to the project root'
    ln --symbolic --force --no-dereference '../..' "roles/${role_name}"
    git add .
    git commit --quiet --message \
      'Make role under test available in test environment'
  fi
}

#}}}
#{{{ fetch_test_branch()
# Usage: fetch_test_branch ENVIRONMENT
#
# with ENVIRONMENT one of ‘docker’ or ‘vagrant’
fetch_test_branch() {
  local environment="${1}"
  local test_branch="${environment}-tests"

  if [ -d "${role_dir}/${test_branch}" ]; then
    log "The test environment ${test_branch} already exists, skipping"
    return
  fi

  log "Setting up ${environment} test environment"
  debug "Fetching test branch ${test_branch} from Github"

  debug 'Create empty branch for the test code'
  pushd "${role_dir}" > /dev/null 2>&1
  debug "Create empty branch for test code in ${role_dir}"
  git checkout --quiet --orphan "${test_branch}"
  git rm -r --force --quiet .
  popd > /dev/null 2>&1

  debug 'Copy test code from skeleton'
  ensure_skeleton_code_is_downloaded
  pushd "${skeleton_download_dir}" > /dev/null 2>&1

  debug "Copy test code from ${skeleton_download_dir}"
  git fetch --quiet origin "${test_branch}"
  git checkout --quiet "${test_branch}"
  rsync --archive --exclude '.git' \
    "${skeleton_download_dir}/" \
    "${role_dir}"
  popd > /dev/null 2>&1

  subst_role_name "${role_dir}"

  debug 'Set up the test branch, commit'
  pushd "${role_dir}" > /dev/null 2>&1
  debug "Committing test code"
  git add .
  git commit --quiet --message \
    "Set up ${environment} test branch from skeleton code"

  debug "Creating worktree for test branch in the master branch"
  git checkout --quiet master 2> /dev/null
  debug "Adding worktree"
  git worktree add "${test_branch}" "${test_branch}" > /dev/null 2>&1
  popd > /dev/null 2>&1
}

#}}}
#{{{ subst_role_name()
# Usage: subst_role_name DIR
# Replace placeholder ROLENAME with the actual role name in the
# specified directory
subst_role_name() {
  local dir="${1}"

  debug "Replacing ROLENAME in ${dir} with actual role name ${role_name}"
  find "${dir}" -type f -exec sed --in-place \
    --expression "s/ROLENAME/${role_name}/g" {} \;
  git add .
}

#}}}
#{{{ cleanup()
# Usage: cleanup
# Delete temporary files
cleanup() {
  debug 'Cleaning up'
  rm -rf "${skeleton_download_dir}"
}

#}}}
#{{{ usage()
# Print usage message on stdout by parsing start of script comments
usage() {
  grep '^#/' "${script_dir}/${script_name}" | sed 's/^#\/\w*//'
}
#}}}
#{{{ logging
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

