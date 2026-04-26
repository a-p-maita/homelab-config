#!/bin/bash
# Script to restart all homelab stacks
set -e
$(dirname "$0")/down-all.sh
$(dirname "$0")/compose-pull-all.sh
$(dirname "$0")/up-all.sh
$(dirname "$0")/setup-uptime-kuma.sh
echo -e "All stacks restarted and updated\n"