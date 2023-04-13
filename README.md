# Execute x86_64 containers on macOS with apple chip (aarch64)

## Description

This repo contains one script that makes it easy to configure `podman` to run x86_64 containers on macOS running on aarch64 (Apple Silicon, M1, ...)

The script creates a VM using `podman machine` and then edits the VM parameters.

By default the created VM mounts `$HOME` (i.e. `/Users/[username]`) so that containers using volumes in the user's home also have access to it (for example, for persistent storage).

## Pre-requisites

macOS >= 12.6

- `jq`
- `curl`
- `podman`

> **Note:** Missing tools can easily be installed with [`brew`](https://brew.sh)

## Usage

Default use:

```bash
./configure.sh
```

Advanced use: override default machine parameters with env vars:

```bash
NAME=intel_64 CPUS=4 RAM_MB=4096 DISK_GB=40 ./configure.sh
```

> **Note:** Those parameters (but `name`, of course) can also be subsequently modified:

```bash
podman machine set --cpus=4 --disk-size=40 --memory=4096 intel_64
```

## VM startup

Often, simple startup results with:

```bash
podman machine start intel_64
```

```text
Starting machine "intel_64"
Waiting for VM ...
Mounting volume... /Users/laurent:/Users/laurent
Error: exit status 255
```

This is due to `qemu` taking too much time to startup the machine and make SSH available soon enough for podman to execute the mount command.

To solve this issue, one way is to slow down `podman`, the script `start.sh` is provided:

```bash
./start.sh intel_64
```

```text
Starting machine "intel_64"
Waiting for VM ...
Pausing podman
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
Waiting for SSH
SSH-2.0-OpenSSH_8.8
Resuming podman
Mounting volume... /Users/laurent:/Users/laurent

This machine is currently configured in rootless mode. If your containers
require root permissions (e.g. ports < 1024), or if you run into compatibility
issues with non-podman clients, you can switch using the following command:

	podman machine set --rootful intel_64

API forwarding listening on: /var/run/docker.sock
Docker API clients default to this address. You do not need to set DOCKER_HOST.

Machine "intel_64" started successfully
```

Et voila !

## Reference

<https://developer.ibm.com/tutorials/running-x86-64-containers-mac-silicon-m1/>

<!-- cSpell:ignore aarch cpus pkill gvproxy -->
