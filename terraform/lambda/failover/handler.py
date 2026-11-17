"""Warm-standby failover runbook.

Triggered by EventBridge when the primary Region's Route 53 health check alarm
goes into ALARM. Runs in the secondary Region.

1. Scale the standby Auto Scaling group up to production size.
2. Optionally promote the Aurora secondary cluster to writer (unplanned
   failover: data written in the last replication-lag window can be lost).
3. Report what happened to SNS.
"""
import json
import os

import boto3

autoscaling = boto3.client("autoscaling")
rds = boto3.client("rds")
sns = boto3.client("sns")


def scale_up_standby():
    asg = os.environ["ASG_NAME"]
    autoscaling.update_auto_scaling_group(
        AutoScalingGroupName=asg,
        MinSize=int(os.environ["ASG_MIN"]),
        DesiredCapacity=int(os.environ["ASG_DESIRED"]),
        MaxSize=int(os.environ["ASG_MAX"]),
    )
    return f"Scaled {asg} to desired={os.environ['ASG_DESIRED']}"


def promote_database():
    if os.environ.get("AUTO_PROMOTE_DB", "false").lower() != "true":
        return "DB promotion skipped (AUTO_PROMOTE_DB=false). Run scripts/promote-secondary-db.sh after confirming the outage."

    global_id = os.environ["GLOBAL_CLUSTER_ID"]
    target = os.environ["SECONDARY_CLUSTER_ARN"]

    members = rds.describe_global_clusters(GlobalClusterIdentifier=global_id)["GlobalClusters"][0]["GlobalClusterMembers"]
    writer = next((m["DBClusterArn"] for m in members if m["IsWriter"]), None)
    if writer == target:
        return "Secondary cluster is already the writer - nothing to do."

    rds.failover_global_cluster(
        GlobalClusterIdentifier=global_id,
        TargetDbClusterIdentifier=target,
        AllowDataLoss=True,  # primary Region is unreachable, so a managed switchover is not possible
    )
    return f"Started Aurora failover of {global_id} to {target}"


def handler(event, context):
    print(json.dumps(event))
    results = []
    for step in (scale_up_standby, promote_database):
        try:
            results.append(step())
        except Exception as exc:  # keep going: a failed DB step must not block compute
            results.append(f"{step.__name__} FAILED: {exc}")

    message = "DR failover runbook executed:\n- " + "\n- ".join(results)
    print(message)
    sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"], Subject="DR failover triggered", Message=message)
    return {"results": results}
