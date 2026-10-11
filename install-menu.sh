#!/usr/bin/env bash
# The installer with a checklist: tick the steps, install them in turn, then
# see how each went. install.sh does everything without asking which.
# Style: https://style.ysap.sh/

# shellcheck source=lib/install-flow.sh
source "${BASH_SOURCE[0]%/*}/lib/install-flow.sh"

run_installer "$@"
