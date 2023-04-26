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
  echo -e $w "$(tput setaf $c)$p$@$s$(tput op)"
}

# extract parameter from config
get_parameter(){
  if test -z "$config";then
    config="$(podman machine inspect $NAME)"
  fi
  echo "$config"|jq -r ".[0].$1"
}

# Create machine
create_machine(){
  mylog check "Checking if machine does not already exist"
  if podman machine inspect $NAME 2> /dev/null 1>&2;then
    mylog warn "Machine already exists: $NAME" 1>&2
    users_home="$HOME"
    config_file=$(podman machine inspect $NAME|jq -r '.[0].ConfigPath.Path')
    return
  fi
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
  # changed '-cpu host' to '-cpu max' to resolve 'Fatal glibc error: CPU does not support x86-64-v2' for RHEL 9 images
  mylog info "Fixing machine $NAME parameters"
  config_file=$(podman machine inspect $NAME|jq -r '.[0].ConfigPath.Path')
  sed \
    -i ''                  `#modify in place`\
    -E                     `#extended syntax`\
    -e '/^  "-[^"]*",$/ N' `#merge option with next line (value)`\
    -e 's|aarch64|x86_64|' `#qemu: change, qemu CPU architecture`\
    -e 's|"host"|"max"|'   `#-cpu: change, enable all CPU features to support RHEL9`\
    -e '/ovmf_vars/ d'     `#-drive: remove, no UEFI firmware`\
    -e '/"-accel",/ d'     `#-accel: remove, use default (tcg)`\
    -e '/"-M",/ d'         `#-machine: remove, use default (pc)`\
    "$config_file"

  mount_tag=$(sed -nEe "s|.*path=$users_home,mount_tag=([^,]+),.*|\1|p" "$config_file")
  if test -z "$mount_tag";then
    mylog error "No mount tag" 1>&2
    exit 1
  fi
  echo "If the user volume mount does not work, you can manually mount with:"
  echo "podman machine ssh $NAME sudo mount -t 9p -o trans=virtio,version=9p2000.L $mount_tag $users_home"
  echo
  echo "Start the machine with:"
  echo "$0 start $NAME"
}

start_machine(){
  # Check if machine exists
  podman machine inspect $NAME > /dev/null || exit 1
  # Check state, propose to reset if state is "starting"
  local state=$(get_parameter State)
  local conf_file=$(get_parameter ConfigPath.Path)
  local starting=$(jq .Starting $conf_file)
  # Sometimes, state is starting in state file, but not in reality
  if test "$starting" = true -a -z "$state";then
    mylog warn "Resetting stale starting state." 1>&2
    tmp=$(mktemp)
    jq '.Starting = false' $conf_file > "$tmp" && mv "$tmp" $conf_file
  fi
  # get machine's SSH port
  export ssh_port=$(get_parameter SSHConfig.Port)
  # start machine in background
  podman machine start $NAME &
  # get podman's PID
  export podmanpid=$!
  # give some time to podman to start qemu
  sleep 3
  # stop podman (pause)
  mylog info 'Pausing podman'
  kill -STOP $podmanpid
  # wait until the SSH server on the qemu vm is available
  while true ;do for spinner in - \\ \| /; do
      # if podman exited due to error, stop waiting
      if ! ps -p $podmanpid > /dev/null;then
          echo 'ERROR: podman exited prematurely'
          exit 1
      fi
      # check if SSH is listening
      if (sleep 1;echo)|nc localhost $ssh_port|grep --quiet '^SSH';then
          # resume podman process
          mylog info "\rSSH available: Resuming podman."
          kill -CONT $podmanpid
          break 2
      fi
      #echo -en "\rWaiting for SSH $spinner"
      mylog check "\rWaiting for SSH $spinner"
      sleep 2
  done;done&
  # wait for subprocesses to complete
  wait
}

check_tool(){
  local tool=$1
  local option=$2
  mylog check "Checking $tool"
  if $tool $option > /dev/null 2>&1;then mylog ok ", $tool found";else
    mylog error "Please install $tool" 1>&2
    exit 1
  fi
}

# get optional machine name
command="$1"
shift
if test ! -z "$1";then
  NAME="$1"
fi

case "$command" in
  create|start)
    check_tool jq --version
    check_tool podman -v
    check_tool curl -V
    ${command}_machine
    ;;
  *)
    echo "Usage: $0 create|start [name]" 1>&2
    exit 1
    ;;
esac
