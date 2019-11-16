# Ansible toolbox

A collection of scripts to be used in conjunction with [`ansible-skeleton`](https://github.com/bertvv/ansible-skeleton) and [`ansible-role-skeleton`](https://github.com/bertvv/ansible-role-skeleton).

## Installation

1. Eiter [download the source](https://github.com/bertvv/ansible-toolbox/archive/master.zip) and extract it somewhere, or clone the repository

    `git clone https://github.com/bertvv/ansible-toolbox.git`

2. Run the installation script: `./install.sh <install-dir>`

The installer will copy all scripts into the specified directory. If you omit the directory, it will copy the scripts into `/usr/local/bin` when invoked by the superuser, or into `~/.local/bin` when run by a normal user. The installation directory must exist.

## The scripts

- `atb-export-vm`: export a VirtualBox VM to an .ova file, removing the shared folder created by Vagrant.
- `atb-get-facts`: list all [facts](https://docs.ansible.com/ansible/playbooks_variables.html#information-discovered-from-systems-facts) (`ansible_*` variables) from a Vagrant box.
- `atb-init`: set up scaffolding code for a Vagrant+Ansible development environment based on <https://github.com/bertvv/ansible-skeleton/>.
- `atb-init-role`: set up scaffolding code for an Ansible role based on <https://github.com/bertvv/ansible-role-skeleton/>.
- `atb-list-variables`: search the current directory (assumed to contain the code for an Ansible role) for role variables, and prints an alphabetical list. The list can also be formatted as a Markdown table, useful for role documentation.
- `atb-provision`: Run `ansible-playbook` on a host managed by Vagrant. The benefit of this (compared to `vagrant provision`) is that you can limit execution to specific hosts (`--limit=<hosts>`) or tags (`--tags=<tags>`), or that you can pass arbitrary options to `ansible-playbook`.
- `atb-role-deps.sh`: Installs all roles mentioned in `ansible/site.yml` from Ansible Galaxy or Github.

Remark that none of the scripts require superuser privileges. Call any of the scripts with option `-h` or `--help` for specific documentation.

## Contributing

Issues, feature requests, ideas are appreciated and can be posted in the Issues section. Pull requests are also very welcome. Preferably, create a topic branch and when submitting, squash your commits into one (with a descriptive message).

## License

BSD

## Author Information

Bert Van Vreckem (bert.vanvreckem@gmail.com)

