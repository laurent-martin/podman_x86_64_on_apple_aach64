#!/bin/bash
machine_name=$1
# get machine's SSH port
export ssh_port=$(podman machine inspect $machine_name|jq -r '.[0].SSHConfig.Port')
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
