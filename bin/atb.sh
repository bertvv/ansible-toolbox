#! /bin/sh
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
readonly black='\e[0;30m'
readonly red='\e[0;31m'
readonly green='\e[0;32m'
readonly yellow='\e[0;33m'
readonly blue='\e[0;34m'
readonly purple='\e[0;35m'
readonly cyan='\e[0;36m'
readonly white='\e[0;37m'

# Script configuration
readonly role_skeleton='https://github.com/bertvv/ansible-role-skeleton'

#}}}

main() {
  command_dispatcher "${@}"
}

#{{{ init_project
init_project() {
  log "init_project ${*}"
}
#}}}
#{{{ init_role
init_role() {
  log "init_role ${*}"
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
Usage: ${SCRIPT_NAME} role [OPTION]... ROLE_NAME

  Generates scaffolding code for an Ansible role based on
  ${role_skeleton}.
  A Git repository is created and the code is committed.

OPTIONS:

EXAMPLES:
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
  printf "${yellow}### %s${reset}\n" "${*}"
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

main "${@}"

