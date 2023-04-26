# Execute x86_64 containers on macOS with apple chip (aarch64)

## Description

A script that makes it easier to configure `podman` to run x86_64 containers on macOS running on aarch64 (Apple Silicon, M1, ...)

In configuration mode, VM is created using `podman machine` and then VM parameters are modified to use x86 emulation instead of local CPU architecture (Apple Chip).
By default the created VM mounts `$HOME` (i.e. `/Users/[username]`) so that containers using volumes in the user's home also have access to it (for example, for persistent storage).

In start mode, it overcomes a problem whereby the VM startup time is too slow for podman to wait and mount the volume.

See [recording](https://asciinema.org/a/n5SCfJGqasOQOv4ntob77AxpF).

## Pre-requisites

macOS >= 12.6

- `jq`
- `curl`
- `podman`

> **Note:** Missing tools can easily be installed with [`brew`](https://brew.sh)

## Virtual Machine: Creation with x86_64 CPU type

Default use:

```bash
./podmac.sh create
```

Advanced use: override default machine parameters with env vars:

```bash
NAME=intel_64 CPUS=4 RAM_MB=4096 DISK_GB=40 ./podmac.sh create
```

> **Note:** Those parameters (but `name`, of course) can also be subsequently modified using `podman`:

```bash
podman machine set --cpus=4 --disk-size=40 --memory=4096 intel_64
```

## Virtual Machine: Startup

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

This is due to the `qemu` emulator taking too much time to startup the machine and make SSH available soon enough for podman to execute the mount command.

> **Note:** Use env var `NAME` like in creation to change the machine name (optional)

The script solves this issue by slowing down `podman`: use the `start` option:

```bash
NAME=intel_64 ./podmac.sh start
```

```text
Starting machine "intel_64"
Waiting for VM ...
Pausing podman
SSH available: Resuming podman.
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

<!-- cSpell:ignore aarch cpus podmac -->
