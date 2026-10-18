#!/usr/bin/env bash
# Compatibility entrypoint. Host policy and disk/lifetime ownership now belong
# to windows-vm; never keep a second direct-Podman autostart implementation.
set -euo pipefail
exec "${WINDOWS_VM_CONTROLLER:-windows-vm}" start
