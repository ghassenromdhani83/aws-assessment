import os
import json
import boto3

# Environment variables passed from Terraform
SNS_TOPIC        = os.environ["SNS_TOPIC"]
EMAIL            = os.environ["EMAIL"]
REPO             = os.environ["REPO"]
REGION           = os.environ["REGION"]
ECS_CLUSTER_NAME = os.environ["ECS_CLUSTER_NAME"]
TASK_DEFINITION  = os.environ["TASK_DEFINITION"]
DEFAULT_SUBNETS  = os.environ["DEFAULT_SUBNETS"].split(",")
DEFAULT_SG       = os.environ["DEFAULT_SG"]

# AWS clients
ecs = boto3.client("ecs", region_name=REGION)
sns = boto3.client("sns", region_name="us-east-1")

def handler(event, context):
    try:
        # Run ECS Fargate task
        ecs_response = ecs.run_task(
            cluster=ECS_CLUSTER_NAME,
            launchType="FARGATE",
            taskDefinition=TASK_DEFINITION,
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": DEFAULT_SUBNETS,
                    "assignPublicIp": "ENABLED",
                    "securityGroups": [DEFAULT_SG]
                }
            }
        )

        # Prepare SNS payload
        payload = {
            "email": EMAIL,
            "source": "ECS",
            "region": REGION,
            "repo": REPO
        }

        sns.publish(
            TopicArn=SNS_TOPIC,
            Message=json.dumps(payload),
            Subject="Candidate Verification"
        )

        # Return ECS task info
        task_arn = ecs_response["tasks"][0]["taskArn"] if ecs_response.get("tasks") else None
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "ECS Task triggered successfully",
                "task_arn": task_arn,
                "region": REGION
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Error triggering ECS Task",
                "error": str(e)
            })
        }
