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
echo Pausing podman
kill -STOP $podmanpid
# wait until the qemu vm presents working SSH server
while true ;do
    # check if SSH header is answered
    if (sleep 1;echo)|nc localhost $ssh_port|grep '^SSH' ;then
        # resume podman process
        echo Resuming podman
        kill -CONT $podmanpid
        break
    fi
    # if podman exited due to error, stop waiting
    if ! ps -p $podmanpid > /dev/null;then
        echo ERROR: podman exited
        exit 1
    fi
    echo Waiting for SSH
    sleep 5
done&
# wait for subprocesses to complete
wait
