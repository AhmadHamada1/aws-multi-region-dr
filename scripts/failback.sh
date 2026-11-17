#!/usr/bin/env bash
# Returns traffic to the primary Region after the drill.
# 1. Restore the primary web tier (Route 53 fails back automatically when healthy).
# 2. If the DB was promoted, switch the writer back with a managed switchover (no data loss).
# 3. Shrink the secondary back to warm-standby size.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
PRIMARY_REGION=$(terraform output -raw primary_region)
SECONDARY_REGION=$(terraform output -raw secondary_region)
PRI_ASG=$(terraform output -raw primary_asg_name)
SEC_ASG=$(terraform output -raw secondary_asg_name)
GLOBAL=$(terraform output -raw aurora_global_cluster_id)

aws autoscaling update-auto-scaling-group --region "$PRIMARY_REGION" \
  --auto-scaling-group-name "$PRI_ASG" --min-size 2 --desired-capacity 2

WRITER=$(aws rds describe-global-clusters --region "$PRIMARY_REGION" --global-cluster-identifier "$GLOBAL" \
  --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter].DBClusterArn' --output text)
if [[ "$WRITER" == *":$SECONDARY_REGION:"* ]]; then
  PRI_ARN=$(aws rds describe-global-clusters --region "$PRIMARY_REGION" --global-cluster-identifier "$GLOBAL" \
    --query 'GlobalClusters[0].GlobalClusterMembers[?!IsWriter].DBClusterArn' --output text)
  echo "Switching Aurora writer back to $PRI_ARN ..."
  aws rds switchover-global-cluster --region "$PRIMARY_REGION" \
    --global-cluster-identifier "$GLOBAL" --target-db-cluster-identifier "$PRI_ARN"
fi

aws autoscaling update-auto-scaling-group --region "$SECONDARY_REGION" \
  --auto-scaling-group-name "$SEC_ASG" --min-size 1 --desired-capacity 1
echo "Failback started. Watch with scripts/watch-failover.sh"
