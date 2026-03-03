import os
import json
import boto3
import uuid

# Environment variables
TABLE_NAME = os.environ["TABLE_NAME"]
EMAIL = os.environ["EMAIL"]
REPO = os.environ["REPO"]
REGION = os.environ["REGION"]
SNS_TOPIC = os.environ["SNS_TOPIC"]

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)
sns = boto3.client("sns", region_name="us-east-1")

def handler(event, context):
    # Create a unique ID for the greeting
    record_id = str(uuid.uuid4())

    # Write to DynamoDB
    table.put_item(Item={"id": record_id, "region": REGION})

    # Publish SNS payload
    payload = {
        "email": EMAIL,
        "source": "Lambda",
        "region": REGION,
        "repo": REPO
    }

    sns.publish(
        TopicArn=SNS_TOPIC,
        Message=json.dumps(payload),
        Subject="Candidate Verification"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Greeting recorded", "region": REGION})
    }
