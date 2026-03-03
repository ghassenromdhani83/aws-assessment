import time
import json
import asyncio
import httpx
import boto3
import os
from typing import Dict

# ====== CONFIGURATION ======
COGNITO_CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID")
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
USERNAME = os.environ.get("EMAIL")
PASSWORD = os.environ.get("COGNITO_USER_PASSWORD")
API_ENDPOINT_US = os.environ.get("API_ENDPOINT_US")
API_ENDPOINT_EU = os.environ.get("API_ENDPOINT_EU")

API_ENDPOINTS = {
    "us-east-1": {
        "greet": f"{API_ENDPOINT_US}/greet",
        "dispatch": f"{API_ENDPOINT_US}/dispatch"
    },
    "eu-west-1": {
        "greet": f"{API_ENDPOINT_EU}/greet",
        "dispatch": f"{API_ENDPOINT_EU}/dispatch"
    }
}

# ====== STEP 1: Authenticate and get JWT ======
def get_jwt_token() -> str:
    client = boto3.client("cognito-idp", region_name="us-east-1")
    resp = client.initiate_auth(
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": USERNAME,
            "PASSWORD": PASSWORD
        },
        ClientId=COGNITO_CLIENT_ID
    )
    return resp["AuthenticationResult"]["IdToken"]


# ====== STEP 2 & 3: Async requests ======
async def call_api(client: httpx.AsyncClient, method: str, url: str, token: str, payload: Dict = None):
    headers = {"Authorization": f"Bearer {token}"}
    start = time.perf_counter()
    if method.upper() == "GET":
        response = await client.get(url, headers=headers)
    else:
        response = await client.post(url, headers=headers, json=payload)
    end = time.perf_counter()
    latency = (end - start) * 1000  # ms
    data = response.json()
    region_match = data.get("region") if "region" in data else "N/A"
    print(f"[{method}] {url} | Status: {response.status_code} | Region: {region_match} | Latency: {latency:.2f}ms | Response: {json.dumps(data)}")
    return data


async def main():
    jwt_token = get_jwt_token()
    async with httpx.AsyncClient() as client:
        tasks = []
        # Greet endpoints
        for region, urls in API_ENDPOINTS.items():
            tasks.append(call_api(client, "GET", urls["greet"], jwt_token))
        # Dispatch endpoints
        dispatch_payload = {"task": "send_greeting", "recipient": USERNAME}
        for region, urls in API_ENDPOINTS.items():
            tasks.append(call_api(client, "POST", urls["dispatch"], jwt_token, payload=dispatch_payload))

        await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())
