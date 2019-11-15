#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: atb-list-variables [-t|--table] [ROLENAME]
#/        atb-list-variables [-h|--help]
#/
#/ Searches the current directory (assumed to contain an Ansible role) for
#/ role variables. This assumes each variable is prefixed with the role
#/ name, e.g. bind_service.
#/
#/ If no ROLENAME was specified explicitly, the name of the current directory
#/ is used.
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
#
# Dependencies:
#
# - coreutils
# - grep
# - sed

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

# Script configuration, default values
formatter='cat'     # How should the output be formatted
prefix="${PWD##*/}" # Role variable prefix (default = current dir)
#}}}

main() {
  check_args "${@}"

  log "Searching for role variables starting with ${prefix}_"
  list_role_variables "${prefix}" \
    | ${formatter}

  log "Variables in vars/ that cannot be set by the user:"
  list_role_variables "${prefix}" vars/*.yml
}

#{{{ Helper functions

# Usage: list_role_variables ROLE [FILE]...
#
# List all role variables with prefix ROLE_ in YAML or Jinja files within the
# current directory.
list_role_variables() {
  local prefix="${1}"
  shift
  local files_to_search=${*:-$(ls ./*/*.yml ./*/*.j2)}

  grep --no-filename --color=never --only-matching \
    "\b${prefix}_.[a-z0-9_]*\b" ${files_to_search} \
    | sort \
    | sed '/^$/d' \
    | uniq
}

# Usage: ... | print_markdown_table
#
# Prints a Markdown-formatted table useful for Ansible role documentation
# with text from stdin (variable names) in the first column
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

# Process command line options
check_args() {
  while [ "$#" -gt '0' ]; do
    case ${1} in
      -h|--help)
        usage
        exit 0
        ;;
      -t|--table)
        formatter=print_markdown_table
        shift
        ;;
      -*)
        error "Unrecognized option: ${1}"
        usage
        exit 2
        ;;
      *)
        prefix="${1}"
        shift
        ;;
    esac
  done
}

# Usage: log [ARG]...
#
# Prints all arguments on the standard error stream
log() {
  printf "${yellow}>>> %s${reset}\\n" "${*}" >&2
}

# Usage: debug [ARG]...
#
# Prints all arguments on the standard error stream,
# if debug output is enabled
debug() {
  [ "${debug}" != 'on' ] || printf "${cyan}### %s${reset}\\n" "${*}" >&2
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf "${red}!!! %s${reset}\\n" "${*}" >&2
}


#}}}

main "${@}"

