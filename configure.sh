#!/bin/bash
# Laurent Martin IBM 2022
# tested on macOS 12.6 with Apple M1 Max
# https://developer.ibm.com/tutorials/running-x86-64-containers-mac-silicon-m1/
# configure podman to run x86_64 containers on ARM Mac

# VM parameters: assign default values
: ${NAME:=intel_64}
: ${CPUS:=4}
: ${RAM_MB:=4096}
: ${DISK_GB:=40}

# simple logging with colors
# @param 1 level (info/error/warn/wait/check/ok/no)
# for colors, see man terminfo
mylog(){
  p=
  w=
  s=
  case $1 in
  info)c=2;;#green
  error)c=1;p='ERROR: ';;#red
  warn)c=3;;#yellow
  wait)c=4;p="$(date) ";;#blue
  check)c=6;w=-n;s=...;;#cyan
  ok)c=2;p=OK;;#green
  no)c=3;p=NO;;#yellow
  *) c=9;;#default
  esac
  shift
  echo $w "$(tput setaf $c)$p$@$s$(tput op)"
}

mylog check "Checking jq"
if jq --version > /dev/null 2>&1;then mylog ok ", jq found";else
  mylog error "Please install jq" 1>&2
  exit 1
fi

mylog check "Checking podman"
if podman -v > /dev/null 2>&1;then mylog ok ", podman found";else
  mylog error "Please install podman" 1>&2
  exit 1
fi

# Check that machine is not already configured
mylog check "Checking if machine does not already exist"
if ! podman machine inspect $NAME 2> /dev/null 1>&2;then mylog ok ", machine does not exist";else
    mylog error "Machine already exists: $NAME" 1>&2
    exit 1
fi

# latest stable coreos
latest_coreos_url=$(curl -s https://builds.coreos.fedoraproject.org/streams/stable.json|jq -r '.architectures.x86_64.artifacts.qemu.formats."qcow2.xz".disk.location')

# the current user HOME folder is forwarded in VM so that persistent storage can be specified in containers and podman volume mounts also works on host
users_home="$HOME"

# Create machine with attributes
# if necessary, those can be changed with `podman machine set`
mylog info "Creating machine: $NAME"
podman machine init \
  --cpus=$CPUS \
  --memory=$RAM_MB \
  --disk-size=$DISK_GB \
  --volume="$users_home:$users_home" \
  --image-path=$latest_coreos_url \
  $NAME

mylog info "Setting machine $NAME as default"
podman system connection default $NAME

# alter qemu configuration to set type as x86 and remove unsupported parameters
mylog info "Fixing machine $NAME parameters"
sed -E \
  -e '/^  "-[^"]*",$/ N' \
  -e 's|aarch64|x86_64|' \
  -e '/ovmf_vars/ d' \
  -e '/"-accel",/ d' \
  -e '/"-cpu",/ d' \
  -e '/"-M",/ d' \
  -i '' \
  $(podman machine inspect $NAME|jq -r '.[0].ConfigPath.Path')
