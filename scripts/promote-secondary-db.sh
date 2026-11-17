#!/usr/bin/env bash
# Unplanned failover of the Aurora Global Database to the secondary Region.
# Use only when the primary Region is really down: writes not yet replicated are lost.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
GLOBAL=$(terraform output -raw aurora_global_cluster_id)
TARGET=$(terraform output -raw aurora_secondary_cluster_arn)
SECONDARY_REGION=$(echo "$TARGET" | cut -d: -f4)

read -r -p "Promote $TARGET to writer (possible data loss)? [y/N] " ok
[[ "$ok" == "y" ]] || exit 1

aws rds failover-global-cluster --region "$SECONDARY_REGION" \
  --global-cluster-identifier "$GLOBAL" --target-db-cluster-identifier "$TARGET" --allow-data-loss
echo "Failover started. Track it with:"
echo "  aws rds describe-global-clusters --region $SECONDARY_REGION --global-cluster-identifier $GLOBAL"
