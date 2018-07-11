#!/usr/bin/env bash

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

source "${__DIR__}/libs/functions.shlib"
source "${__DIR__}/libs/remote_exec.shlib"

set -E
trap 'throw_exception' ERR

add_to_inventory() {
  for host in "${@}"; do
    consolelog "adding ${host} to inventory..."

    if [[ -z "${ssh_pass}" ]]; then
      echo "${host} ansible_user=${SSH_USER}" >> inventory-temp
      remote_exec "${SSH_USER}@${host}" "dpkg -l | grep sudo || (apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -y -qq install sudo)"
      remote_exec "${SSH_USER}@${host}" "sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install python"
      if [[ "${SSH_USER}" != "bofh" ]]; then
        remote_exec "${SSH_USER}@${host}" "id -u bofh || sudo useradd -d /home/bofh -m -s /bin/bash bofh"
      fi
    else
      echo "${host} ansible_user=${SSH_USER} ansible_ssh_pass=${ssh_pass} ansible_sudo_pass=${ssh_pass}" >> inventory-temp
      remote_exec "${SSH_USER}@${host}" "dpkg -l | grep sudo || (apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -y -qq install sudo)" "${ssh_pass}"
      remote_exec "${SSH_USER}@${host}" "echo '${ssh_pass}' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get -y -qq install python" "${ssh_pass}"
      if [[ "${SSH_USER}" != "bofh" ]]; then
        remote_exec "${SSH_USER}@${host}" "echo '${ssh_pass}' | sudo -S useradd -d /home/bofh -m -s /bin/bash bofh" "${ssh_pass}"
      fi
    fi
  done
}

add_to_known_hosts() {
  local host_ip

  for host in "${@}"; do
    consolelog "adding ${host} to known_hosts..."
    host_ip="$(dig +short "${host}")"
    ssh-keygen -f ~/.ssh/known_hosts -R "${host}" &> /dev/null
    ssh-keygen -f ~/.ssh/known_hosts -R "${host_ip}" &> /dev/null
    ssh-keyscan -T 30 -p 22 "${host}" >> ~/.ssh/known_hosts 2> /dev/null
  done
}

usage() {
cat <<EOF
Usage: ${0##*/} [OPTIONS] TASK HOSTS...
bootstrap ansible hosts

Options:
    -h              display this help and exit
    -u              initial ssh user (default: bofh)

Tasks:
    known-hosts     add HOSTS to known_hosts
    bootstrap       bootstrap HOSTS
EOF
}

OPTIND=1

while getopts "hu:" opt; do
  case "${opt}" in
    h )
      usage
      exit 0
      ;;
    u )
      SSH_USER="${OPTARG}"
      ;;
    '?' )
      usage >&2
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

if [[ -z "${SSH_USER}" ]]; then
  SSH_USER="bofh"
fi

# tasks
task="${1}"
shift

case "${task}" in
  known-hosts )
    add_to_known_hosts "${@}"
    ;;

  bootstrap )
    read -rsp "optional ssh password for '${SSH_USER}' (hidden): " ssh_pass
    echo ""

    ssh_keys=()
    while :; do
      read -p "ssh pubkey: " ssh_key
      if [[ -z "${ssh_key}" ]]; then
        break
      else
        ssh_keys+=( "${ssh_key}" )
      fi
    done

    rm -f inventory-temp
    add_to_inventory "${@}"

    # password-less sudoer
    ansible all -i inventory-temp -m lineinfile -ba "path=/etc/sudoers.d/100-no-pass-users line='bofh ALL=(ALL) NOPASSWD:ALL' create=yes mode=0440 validate='/usr/sbin/visudo -cf %s'"
    ansible all -i inventory-temp -m lineinfile -ba "path=/etc/sudoers.d/100-no-pass-users line='Defaults:bofh "'!'"requiretty' create=yes mode=0440 validate='/usr/sbin/visudo -cf %s'"

    # create .ssh
    ansible all -i inventory-temp -m file --become-user=bofh -ba "path=~/.ssh mode=0750 state=directory"
    for ssh_key in "${ssh_keys[@]}"; do
      ansible all -i inventory-temp -m lineinfile --become-user=bofh -ba "path=~/.ssh/authorized_keys create=yes mode=0640 line='${ssh_key}'"
    done

    # cleanup
    rm -f inventory-temp
    ;;
esac

#remote_exec "bofh@${host}" "{ sleep 2; sudo reboot; } >/dev/null &"
#ansible all -i inventory -m command -ba 'whoami'
