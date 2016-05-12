# Ansible toolbox

A collection of scripts to be used in conjunction with [`ansible-skeleton`](https://github.com/bertvv/ansible-skeleton) and [`ansible-role-skeleton`](https://github.com/bertvv/ansible-role-skeleton).

## Installation

1. Eiter [download the source](https://github.com/bertvv/ansible-toolbox/archive/master.zip) and extract it somewhere, or clone the repository

    `git clone https://github.com/bertvv/ansible-toolbox.git`

2. Run the installation script: `./install.sh <install-dir>`

The installer will copy all scripts into the specified directory. If you omit the directory, it will copy the scripts into `/usr/local/bin` when invoked by the superuser, or into `~/bin` when run by a normal user. The installation directory must exist.

## The scripts

- **`atb-export-vm`**: export a VirtualBox VM to an .ova file, removing the shared folder created by Vagrant.
- **`atb-get-vars`**: list all [facts](https://docs.ansible.com/ansible/playbooks_variables.html#information-discovered-from-systems-facts) (`ansible_*` variables) from a Vagrant box.
- **`atb-init-role`**: set up scaffolding code for an Ansible role based on <https://github.com/bertvv/ansible-role-skeleton/>. (Requires Git v2.5.0 for [git-worktree](https://git-scm.com/docs/git-worktree)).
- **`atb-init`**: set up scaffolding code for a Vagrant+Ansible development environment based on <https://github.com/bertvv/ansible-skeleton/>.
- **`atb-provision`**: Run `ansible-playbook` on a host managed by Vagrant. The benefit of this is that you can limit execution to specific hosts (`--limit=<hosts>`) or tags (`--tags=<tags>`). All options specified on the command line are passed on to `ansible-playbook`.
- **`atb-role-deps.sh`**: Installs all roles mentioned in `ansible/site.yml`.

Remark that none of the scripts require superuser privileges.

## Contributing

Issues, feature requests, ideas are appreciated and can be posted in the Issues section. Pull requests are also very welcome. Preferably, create a topic branch and when submitting, squash your commits into one (with a descriptive message).

## License

BSD

## Author Information

Bert Van Vreckem (bert.vanvreckem@gmail.com)

