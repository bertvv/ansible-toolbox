#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# Ansible toolbox - automate some tedious tasks when setting up a project,
# role, ... for Ansible.

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

# Color definitions
readonly reset='\e[0m'
readonly red='\e[0;31m'
readonly yellow='\e[0;33m'
readonly cyan='\e[0;36m'

# Show debug output when value is "on"
readonly debug_mode='on'

# Script configuration
readonly role_skeleton='https://github.com/bertvv/ansible-role-skeleton'
readonly skeleton_download_dir="$(mktemp --directory)"
#}}}

main() {
  command_dispatcher "${@}"
}

#{{{ init_project
init_project() {
  debug "init_project ${*}"
}
#}}}
#{{{ init_role
init_role() {
  debug "Parameters: ${*}"

  local test_env='none'
  local optspec=':t:-:'

  # TODO: check if nonexisting options are parsed correctly
  # i.e. give an error. Also see fancylongpw.

  while getopts "${optspec}" optchar; do
    case "${optchar}" in
      -)
        case "${OPTARG}" in
          tests)
            opt_arg="${!OPTIND}"; OPTIND=$(( OPTIND + 1))
            debug "Parsing option: --${OPTARG}, arg: ${opt_arg}"
            test_env="${opt_arg}"
            ;;
          tests=*)
            opt_arg="${OPTARG#*=}"
            opt="${OPTARG%=$opt_arg}"
            debug "Parsing option: --${opt}, arg: ${opt_arg}"
            test_env="${opt_arg}"
            ;;
          *)
            if [ "${OPTERR}" = '1' ] && [ "${optspec:0:1}" != ':' ]; then
              error "Unknown option: --${OPTARG}"
            fi
            ;;
        esac
        ;;
      t)
        debug "Parsing option: -${optchar}, arg: ${OPTARG}"
        test_env="${OPTARG}"
        ;;
      *)
        if [ "${OPTERR}" = '1' ] && [ "${optspec:0:1}" != ':' ]; then
          error "Unknown option: --${OPTARG}"
        fi
        ;;
    esac
  done

  shift $((OPTIND-1))

  debug "Parameters: ${*}"
  debug "Test environment(s): ${test_env}"

  if [ "${#}" -eq 0 ]; then
    error "No role name specified! Bailing out"
    exit 2
  fi

  local role_name="${1}"

  info "Initializing role ${role_name}"

  init_role_dir "${role_name}"
  setup_test_environments "${role_name}" "${test_env}"

  cleanup
}

#}}}
#{{{ init_role_dir
# Usage: init_role_dir ROLE_NAME
init_role_dir() {
  local role_name="${1}"
  local current_dir="${PWD##*/}"

  if [ "${current_dir}" = "${role_name}" ]; then
    debug "We're inside the role directory, going to parent directory"
    cd ..
  fi

  local role_dir="${PWD}/${role_name}"

  if [ -d "${role_dir}" ]; then
    info "A directory with name ‘${role_name}’ already exists, skipping this step"
    return
  fi

  ensure_skeleton_code_is_downloaded

  info "Creating local directory for the role"
  mkdir "${role_name}"

  debug 'Copy the role skeleton code'
  rsync --archive --exclude '.git' "${skeleton_download_dir}/" "${role_dir}"

  subst_role_name "${role_dir}" "${role_name}"

  debug "Setting year in the LICENSE file"
  sed --in-place --expression "s/YEAR/$(date +%Y)/" "${role_dir}/LICENSE.md"

  info "Initializing Git repository, first commit"
  pushd "${role_dir}" > /dev/null 2>&1
  git init --quiet
  git add .
  git commit --quiet --message "First commit from role skeleton"
  popd > /dev/null 2>&1
}

#}}}
#{{{ ensure_skeleton_code_is_downloaded
ensure_skeleton_code_is_downloaded() {

  if [ ! -d "${skeleton_download_dir}/.git" ]; then
    debug "Downloading skeleton code from Github"
    git clone --quiet "${role_skeleton}" "${skeleton_download_dir}"
  fi

}

#}}}
#{{{ setup_test_environments
# Usage: setup_test_environments ROLE_NAME ENVIRONMENT...
#
# With ENVIRONMENT one of none, vagrant, or docker, or a comma-separated list
# of the desired test environments
setup_test_environments() {
  local role_name="${1}"
  local environments

  # Split comma separated environment names into an array
  IFS=',' read -ra environments <<< "${2}"

  for environment in "${environments[@]}"; do
    debug "Setting up test env: ${environment}"
    case "${environment}" in
      'none')
        return
        ;;
      'vagrant')
        setup_vagrant_environment "${role_name}"
        ;;
      'docker')
        setup_docker_environment "${role_name}"
        ;;
      *)
        error "Test environment ${environment} is not defined, skipping"
        ;;
    esac
  done

}

#}}}
#{{{ setup_docker_environment
# Usage: setup_docker_environment ROLE_NAME
setup_docker_environment() {
  local role_name="${1}"
  local role_dir="${PWD}/${role_name}"

  fetch_test_branch "${role_name}" 'docker'

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
#{{{ setup_vagrant_environment
# Usage: setup_vagrant_environment ROLE_NAME
setup_vagrant_environment() {
  local role_name="${1}"
  local role_dir="${PWD}/${role_name}"

  fetch_test_branch "${role_name}" 'vagrant'

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
#{{{ fetch_test_branch
# Usage: fetch_test_branch ROLE_NAME ENVIRONMENT
#
# with ENVIRONMENT one of ‘docker’ or ‘vagrant’
fetch_test_branch() {
  local role_name="${1}"
  local role_dir="${PWD}/${role_name}"
  local environment="${2}"
  local test_branch="${environment}-tests"

  if [ -d "${role_dir}/${test_branch}" ]; then
    info "The test environment ${test_branch} already exists, skipping"
    return
  fi

  info "Setting up ${environment} test environment"
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
  subst_role_name "${role_dir}" "${role_name}"
  popd > /dev/null 2>&1

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
#{{{ subst_role_name
# Usage: subst_role_name DIR NAME
# Replace placeholder ROLENAME with the actual role name in the
# specified directory
subst_role_name() {
  local dir="${1}"
  local role_name="${2}"

  debug "Replacing ROLENAME in ${dir} with actual role name ${role_name}"
  find "${dir}" -type f -exec sed --in-place \
    --expression "s/ROLENAME/${role_name}/g" {} \;
}

#}}}
#{{{ cleanup
# Usage: cleanup
# Delete temporary files
cleanup() {
  debug 'Cleaning up'
  rm -rf "${skeleton_download_dir}"
}

#}}}
#{{{ command_dispatcher
# Usage: command_dispatcher [PARAMETER]...
# Determines the command and calls the appropriate function to execute that
# command.
command_dispatcher() {
  # No parameters passed: print help message and exit
  if [ "${#}" -eq "0" ]; then
    usage
    exit 0
  fi
  case "${1}" in
    'help' )
      shift
      show_usage "${@}"
      exit 0
      ;;
    'project' )
      shift
      init_project "${@}"
      ;;
    'role' )
      shift
      init_role "${@}"
      ;;
    * )
      error "Command ${1} does not exist"
      usage
      exit 2
      ;;
  esac
}
#}}}
#{{{ usage
# Show an appropriate help message
show_usage() {
  if [ "${#}" -eq "0" ]; then
    usage
    exit 0
  else
    local command="${1}"
    case "${command}" in
      'project' )
        usage_project
        exit 0
        ;;
      'role' )
        usage_role
        exit 0
        ;;
      *)
        error "Command ${command} does not exist"
        usage
        exit 2
        ;;
    esac
  fi
}

# Print usage message on stdout
usage() {
cat << _EOF_
Usage: ${SCRIPT_NAME} [COMMAND [OPTION]... [ARG]...]

  Ansible toolbox -- automate the setup of an infrastructure development
  environment for Ansible.

COMMANDS:

  help [COMMAND]
            Shows this help message, or command specific help when specified.
  project
            Initializes a project powered by a Vagrant environment.
  role
            Generates scaffolding code for an Ansible role.

EXAMPLES:

  atb help role

            Shows help for the 'role' command.

  atb project --role=bertvv.rh-base,geerlingguy.apache webserver

            Creates a project and installs the two specified roles.

  atb role --tests=docker,vagrant nginx

            Creates a role named 'nginx' and initializes test environments with
            both Vagrant and Docker.
_EOF_
}

# Print usage message for command `role` on stdout
usage_role() {
cat << _EOF_
Usage: ${SCRIPT_NAME} role [OPTION]... ROLE

  Generates scaffolding code for an Ansible role based on
  ${role_skeleton}.
  A Git repository is created and the code is committed.

OPTIONS:

  -t, --tests=TESTENV...

            Initializes a test environment for a new or existing ROLE

EXAMPLES:

  atb role --tests=docker,vagrant nginx

            Creates a role named 'nginx' and initializes test environments with
            both Vagrant and Docker.

            When the role already exists, only the test environments are set
            up.
_EOF_
}

# Print usage message for command `project` on stdout
usage_project() {
cat << _EOF_
Usage: ${SCRIPT_NAME} project [OPTION]... PROJECT_NAME

  Generates scaffolding code for an Ansible infrastructure coding environment
  powered by Vagrant. A git repository is created and the code is committed.

OPTIONS:

EXAMPLES:
_EOF_
}
#}}}
#{{{ Logging
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
  if [ "${debug_mode}" = 'on' ]; then
    printf "${cyan}### %s${reset}\n" "${*}"
  fi
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf "${red}!!! %s${reset}\n" "${*}" 1>&2
}
#}}}

main "${@}"

