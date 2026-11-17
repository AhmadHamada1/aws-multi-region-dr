#!/usr/bin/env bash
# Simulates an outage of the primary Region's web tier by scaling its ASG to 0.
# The ALB starts returning 503, the Route 53 health check fails, DNS fails over,
# the CloudWatch alarm fires and the failover Lambda scales up the standby.
set -euo pipefail
cd "$(dirname "$0")/../terraform"

PRIMARY_REGION=$(terraform output -raw primary_region)
ASG=$(terraform output -raw primary_asg_name)

echo "Scaling $ASG in $PRIMARY_REGION to 0 ..."
aws autoscaling update-auto-scaling-group --region "$PRIMARY_REGION" \
  --auto-scaling-group-name "$ASG" --min-size 0 --desired-capacity 0
echo "Done. Run scripts/watch-failover.sh to watch traffic move to the secondary Region."
