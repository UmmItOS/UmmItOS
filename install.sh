#!/usr/bin/env bash
# The installer without choices: everything this machine can use, after one
# question. install-menu.sh lets you pick the steps. Style: https://style.ysap.sh/

# shellcheck source=lib/install-flow.sh
source "${BASH_SOURCE[0]%/*}/lib/install-flow.sh"

run_installer --all "$@"
