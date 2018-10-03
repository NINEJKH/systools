#!/usr/bin/env bash
#
# create vbox guests
#

readlink_bin="${READLINK_PATH:-readlink}"
if ! "${readlink_bin}" -f test &> /dev/null; then
  __DIR__="$(dirname "$(python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${0}")")"
else
  __DIR__="$(dirname "$("${readlink_bin}" -f "${0}")")"
fi

source "${__DIR__}/libs/functions.shlib"

set -E
trap 'throw_exception' ERR

usage() {
cat <<EOF
Usage: ${0##*/} OPTIONS
vbox creator

    -h          display this help and exit
    -b STRING   base folder (required)
    -B STRING   bridge adapter (default: eth0)
    -c NUMBER   number of vCPUs (required)
    -i STRING   path to boot iso
    -l STRING   RDP IP:PORT (required)
    -m NUMBER   memory in MB (required)
    -M STRING   mac address
    -n STRING   vbox name (default: base)
    -s NUMBER   disk in MB
EOF
}

OPTIND=1

while getopts "hb:B:c:i:l:m:M:n:s:" opt; do
  case "${opt}" in
    h )
      usage
      exit 0
      ;;
    b )
      VBOX_BASEDIR="${OPTARG}"
      ;;
    B )
      VBOX_BRIDGE_IFACE="${OPTARG}"
      ;;
    c )
      VBOX_CPUS="${OPTARG}"
      ;;
    i )
      VBOX_ISO="${OPTARG}"
      ;;
    l )
      VBOX_RDP_IP="${OPTARG%:*}"
      VBOX_RDP_PORT="${OPTARG#*:}"
      ;;
    m )
      VBOX_MEMORY="${OPTARG}"
      ;;
    M )
      VBOX_MAC="--macaddress1 ${OPTARG}"
      ;;
    n )
      VBOX_NAME="${OPTARG}"
      ;;
    s )
      VBOX_STORAGE="${OPTARG}"
      ;;
    '?' )
      usage >&2
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

# check if required vars were set
required_vars=( \
  VBOX_BASEDIR \
  VBOX_CPUS \
  VBOX_MEMORY \
  VBOX_RDP_IP \
  VBOX_RDP_PORT \
)

for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var}" ]]; then
    echo "required var missing (${required_var})" 1>&2
    exit 2
  fi
done

if [[ -z "${VBOX_NAME}" ]]; then
  VBOX_NAME=base
fi

if [[ "${VBOX_ISO}" == "ubuntu-"* ]]; then
  ostype='Ubuntu_64'
else
  ostype='Debian_64'
fi

if [[ -z "${VBOX_BRIDGE_IFACE}" ]]; then
  VBOX_BRIDGE_IFACE="eth0"
fi

consolelog "creating vbox"
vbox_uuid=$(VBoxManage \
  createvm \
  --name "${VBOX_NAME}" \
  --ostype "${ostype}" \
  --basefolder "${VBOX_BASEDIR}" \
  --register \
  | grep -F UUID \
  | cut -d' ' -f2)
consolelog " - ${vbox_uuid}" "success"

consolelog "creating vbox"
VBoxManage \
  modifyvm "${vbox_uuid}" \
  --cpus "${VBOX_CPUS}" \
  --memory "${VBOX_MEMORY}" \
  --vrdeport "${VBOX_RDP_PORT}" \
  --vrdeaddress "${VBOX_RDP_IP}" \
  --acpi on \
  --ioapic on \
  --apic on \
  --x2apic on \
  --paravirtprovider kvm \
  --hwvirtex on \
  --nestedpaging on \
  --largepages on \
  --vtxvpid on \
  --vtxux on \
  --pae on \
  --longmode on \
  --rtcuseutc on \
  --accelerate3d off \
  --accelerate2dvideo off \
  --firmware bios \
  --bioslogofadein off \
  --bioslogofadeout off \
  --boot1 dvd \
  --boot2 disk \
  --nic1 bridged \
  --bridgeadapter1 "${VBOX_BRIDGE_IFACE}" \
  ${VBOX_MAC} \
  --audio none \
  --clipboard disabled \
  --draganddrop disabled \
  --vrde on \
  --vrdeauthtype external \
  --defaultfrontend headless

consolelog "creating sata controller"
VBoxManage \
  storagectl "${vbox_uuid}" \
  --name 'SATA Controller' \
  --add sata \
  --portcount 2 \
  --hostiocache off \
  --bootable on

if [[ ! -z "${VBOX_STORAGE}" ]]; then
  consolelog "creating disk"
  VBoxManage \
    createmedium disk \
    --filename "${VBOX_BASEDIR}/${VBOX_NAME}/${VBOX_NAME}.vdi" \
    --size "${VBOX_STORAGE}" > /dev/null
  # Medium created. UUID: 79725d5f-5f5a-40be-a935-cd6b518384e6

  consolelog "attaching disk"
  VBoxManage \
    storageattach "${vbox_uuid}" \
    --storagectl 'SATA Controller' \
    --port 1 \
    --device 0 \
    --type hdd \
    --medium "${VBOX_BASEDIR}/${VBOX_NAME}/${VBOX_NAME}.vdi"
fi

if [[ ! -z "${VBOX_ISO}" ]]; then
  consolelog "attaching iso"
  VBoxManage \
    storageattach "${vbox_uuid}" \
    --storagectl 'SATA Controller' \
    --port 2 \
    --device 0 \
    --type dvddrive \
    --medium "${VBOX_ISO}"
fi

if [[ ! -z "${VBOX_STORAGE}" ]]; then
  consolelog "launching vbox"
  VBoxManage startvm "${vbox_uuid}" > /dev/null
fi

consolelog "DONE!" "success"
