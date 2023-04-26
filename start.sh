#!/bin/bash
machine_name=$1
if test -z "$machine_name";then
    echo "Usage: $0 <machine name>" 1>&2
    exit 1
fi
# Check jq is installed
jq -h>/dev/null || exit 1
# Check if machine exists
podman machine inspect $machine_name > /dev/null || exit 1
# Get configuration
config="$(podman machine inspect $machine_name)"
# extract parameter from config
get_parameter(){
    echo "$config"|jq -r ".[0].$1"
}
# Check state, propose to reset if state is "starting"
conf_file=$(get_parameter ConfigPath.Path)
state=$(get_parameter State)
case "$state" in
*ing)
    if test "$2" = -f;then
        echo "Resetting state."
        tmp=$(mktemp)
        jq '.Starting = false' $conf_file > "$tmp" && mv "$tmp" $conf_file
    else
        echo "Machine state: $state" 1>&2
        echo "To reset state and force start, execute:" 1>&2
        echo "$0 $* -f" 1>&2
        exit 1
    fi
esac
# get machine's SSH port
export ssh_port=$(get_parameter SSHConfig.Port)
# start machine in background
podman machine start $machine_name &
# get podman's PID
export podmanpid=$!
# give some time to podman to start qemu
sleep 3
# stop podman (pause)
echo 'Pausing podman'
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
        echo -e "\rSSH available: Resuming podman."
        kill -CONT $podmanpid
        break 2
    fi
    echo -en "\rWaiting for SSH $spinner"
    sleep 2
done;done&
# wait for subprocesses to complete
wait
