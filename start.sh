#!/bin/bash
machine_name=$1
# get machine's SSH port
export ssh_port=$(podman machine inspect $machine_name|jq -r '.[0].SSHConfig.Port')
# start machine in background
podman machine start $machine_name &
# get the PID
export podmanpid=$!
# give some startup time
sleep 3
# stop podman
echo Pausing podman
kill -STOP $podmanpid
# wait for qemu machine to present working SSH server
while true ;do
    if (sleep 1;echo)|nc localhost $ssh_port|grep '^SSH' ;then
        # continue podman
        echo Resuming podman
        kill -CONT $podmanpid
        break
    fi
    if ! ps -p $podmanpid > /dev/null;then
        echo ERROR: podman exited
        exit 1
    fi
    echo Waiting for SSH
    sleep 5
done&
# wait for subprocesses to complete
wait
