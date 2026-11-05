#!/usr/bin/env bash
# The installer: tick the steps, install them in turn, then see how each went.
# The only installer entry point. Style: https://style.ysap.sh/

# shellcheck source=lib/install-flow.sh
source "${BASH_SOURCE[0]%/*}/lib/install-flow.sh"

run_installer "$@"
