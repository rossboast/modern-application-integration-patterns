import boto3
import os
import json
from botocore.exceptions import ClientError
from boto3 import dynamodb

CONNECTIONS_TABLE_NAME = os.environ.get("CONNECTIONS_TABLE_NAME")
RESULTS_TABLE_NAME = os.environ.get("RESULTS_TABLE_NAME")
API_REGION = os.environ.get("API_REGION")
API_ENDPOINT_URL = os.environ.get("WEBSOCKET_CALLBACK_URL")

ddb = boto3.resource("dynamodb")

apiManagement = boto3.client(
    "apigatewaymanagementapi", region_name=API_REGION, endpoint_url=API_ENDPOINT_URL
)

connections_table = ddb.Table(CONNECTIONS_TABLE_NAME)
results_table = ddb.Table(RESULTS_TABLE_NAME)


class UnableToAccessDatabaseException(Exception):
    pass


class NoAvailableWebSocketConnectionException(Exception):
    pass


class NoAvailableResultsException(Exception):
    pass


def get_database_item(table, key):
    try:
        ddb_response = table.get_item(Key=key)
    except ClientError as error:
        msg = error.response["Error"]["Message"]
        print(msg)
        raise UnableToAccessDatabaseException(msg) from error
    return ddb_response


def lambda_handler(event, context):
    print("event:", event)
    currentExecutionArn = event.get("executionArn")
    database_key = {"ExecutionArn": currentExecutionArn}

    results_response = get_database_item(results_table, database_key)

    if not results_response.get("Item"):
        raise NoAvailableResultsException

    connections_response = get_database_item(connections_table, database_key)

    # no item indicates no WebSocket connection has been opened to send the result back to
    if not connections_response.get("Item"):
        raise NoAvailableWebSocketConnectionException

    result_item = results_response["Item"]
    result_item_json = json.dumps(result_item)
    execution_websocket_connection = connections_response["Item"]["WsClientId"]

    ws_response = apiManagement.post_to_connection(
        ConnectionId=execution_websocket_connection, Data=result_item_json
    )
    return {"result_item": result_item}
