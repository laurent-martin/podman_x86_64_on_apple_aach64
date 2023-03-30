# Execute x86_64 containers on macOS with apple chip (aarch64)

## Reference

<https://developer.ibm.com/tutorials/running-x86-64-containers-mac-silicon-m1/>

## Description

This repo contains one script that makes it easy to configure podman to run x86_64 containers on macOS running on aarch64 (Apple Silicon, M1, ...)

The script creates a VM using `podman machine` and then edits the VM parameters

By default the created VM mounts `$HOME` (i.e. `/Users/[username]`) so that containers using volumes in the user's home also have access to it (for example, for persistent storage).

## Pre-requisites

macOS >= 12.6

- `jq`
- `curl`
- `podman`

> Missing tools can easily be installed with [`brew`](https://brew.sh)

## Usage

Default use:

```bash
./configure.sh
```

Advanced use: override default machine parameters with env vars:

```bash
NAME=intel_64 CPUS=4 RAM_MB=4096 DISK_GB=40 ./configure.sh
```

> Those parameters (but name) can also be subsequently modified:

```bash
podman machine set --cpus=4 --disk-size=40 --memory=4096 intel_64
```

## VM startup

The script does not start the VM, but it display the command to start the VM.
The VM startup time will last a bit due to pure emulation without acceleration.

Often, simple startup results with:

```bash
podman machine start intel_64

Starting machine "intel_64"
Waiting for VM ...
Mounting volume... /Users:/Users
Error: exit status 255
```

This is due to qemu taking too much time to startup the machine (due to slowness...).

To solve this issue, one way is to slow down `podman`, and give an extra minute for `qemu` to start the machine:

```bash
podman machine start intel_64 && sleep 3 && pkill -STOP podman gvproxy && sleep 60 && pkill -CONT podman gvproxy

Starting machine "intel_64"
Waiting for VM ...
Mounting volume... /Users/laurent:/Users/laurent

Machine "intel_64" started successfully
```

Et voila !

<!-- cSpell:ignore aarch cpus pkill gvproxy -->
