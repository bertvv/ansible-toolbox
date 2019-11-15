#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: atb-list-variables [-t|--table] ROLENAME
#/        atb-list-variables [-h|--help]
#/
#/ Searches the current directory (assumed to contain an Ansible role) for
#/ role variables. This assumes each variable is prefixed with the role
#/ name, e.g. bind_service.
#/
#/ OPTIONS
#/   -h, --help
#/                Print this help message
#/   -t, --table
#/                Print the variables as a Markdown table, suitable for
#/                role documentation.
#/
#/ EXAMPLES
#/  atb-list-variables bind
#/  atb-list-variables --table vsftpd

#{{{ Bash settings
# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail
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

formatter='cat'  # How should the output be formatted
prefix=''        # Role variable prefix
#}}}

main() {
  check_args "${@}"
  list_role_variables "${prefix}" \
    | ${formatter}
}

#{{{ Helper functions

# Usage: list_role_variables ROLE
#
# List all role variables with prefix ROLE_ in YAML or Jinja files within the
# current directory.
list_role_variables() {
  local prefix="${1}"

  ag --nofilename --nocolor --nonumbers --only-matching \
    "\b${prefix}_.[a-z0-9_]*\b" ./*/*.yml ./*/*.j2 \
    | sort \
    | uniq
}

print_markdown_table() {
  printf '| Variable | Default | Comment |\n'
  printf '| :---     | :---    | :---    |\n'
  while read -r line
  do
    printf '| `%s` |  |  |\n' "${line}"
  done
}

# Print usage message on stdout by parsing start of script comments
usage() {
  grep '^#/' "${script_dir}/${script_name}" | sed 's/^#\/\w*//'
}

check_args() {
  if [ "${#}" -eq '0' ]; then
    error "Expected at least 1 argument, but got ${#}"
    usage
    exit 1
  elif [ "${1}" = '-h' ] || [ "${1}" = '--help' ]; then
    usage
    exit 0
  elif [ "${1}" = '-t' ] || [ "${1}" = '--table' ]; then
    formatter=print_markdown_table
    shift
  fi
  if [ "${#}" -ge 1 ]; then
    prefix="${1}"
  else
    error "No role name prefix specified!"
    usage
    exit 1
  fi
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

