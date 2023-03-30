#!/bin/bash
# configure podman to run x86_64 containers on ARM Mac
# Laurent Martin IBM 2022
# tested on macOS 12.6 with Apple M1 Max
# https://developer.ibm.com/tutorials/running-x86-64-containers-mac-silicon-m1/

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
  info) c=2;;
  error) c=1;p='ERROR: ';;
  warn) c=3;;
  wait) c=4;p="$(date) ";;
  check) c=6;w=-n;s=...;;
  ok) c=2;p=OK;;
  no) c=3;p=NO;;
  *) c=9;;
  esac
  shift
  echo $w "$(tput setaf $c)$p$@$s$(tput op)"
}

# main
create_machine(){
  # latest stable coreos
  latest_coreos_url=$(curl -s https://builds.coreos.fedoraproject.org/streams/stable.json|jq -r '.architectures.x86_64.artifacts.qemu.formats."qcow2.xz".disk.location')

  # the current user HOME folder is forwarded in VM so that persistent storage can be specified in containers and podman volume mounts also works on host
  users_home="$HOME"

  #podman_socket=$HOME/.local/share/containers/podman/machine/$NAME/podman.sock
  #  --volume="$podman_socket:/var/run/docker.sock:rw,security_model=none" \

  # Create machine with attributes
  # if necessary, those can be changed with `podman machine set`
  mylog info "Creating machine: $NAME"
  podman machine init \
    --cpus=$CPUS \
    --memory=$RAM_MB \
    --disk-size=$DISK_GB \
    --volume="$users_home:$users_home:rw,security_model=none" \
    --image-path=$latest_coreos_url \
    $NAME

  mylog info "Setting machine $NAME as default"
  podman system connection default $NAME

  # alter qemu configuration to set type as x86 and remove unsupported parameters
  mylog info "Fixing machine $NAME parameters"
  config_file=$(podman machine inspect $NAME|jq -r '.[0].ConfigPath.Path')
  sed -E \
    -e '/^  "-[^"]*",$/ N' \
    -e 's|aarch64|x86_64|' \
    -e '/ovmf_vars/ d' \
    -e '/"-accel",/ d' \
    -e '/"-cpu",/ d' \
    -e '/"-M",/ d' \
    -i '' \
    "$config_file"
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

mylog check "Checking if machine does not already exist"
if ! podman machine inspect $NAME 2> /dev/null 1>&2;then
  mylog ok ", machine does not exist"
  create_machine
else
  mylog warn "Machine already exists: $NAME" 1>&2
  users_home="$HOME"
  config_file=$(podman machine inspect $NAME|jq -r '.[0].ConfigPath.Path')
fi

mount_tag=$(sed -nEe "s|.*path=$users_home,mount_tag=([^,]+),.*|\1|p" "$config_file")
if test -z "$mount_tag";then
  mylog error "No mount tag" 1>&2
  exit 1
fi
echo "If the user volume mount does not work, you can manually mount with:"
echo "podman machine ssh $NAME sudo mount -t 9p -o trans=virtio,version=9p2000.L $mount_tag $users_home"
