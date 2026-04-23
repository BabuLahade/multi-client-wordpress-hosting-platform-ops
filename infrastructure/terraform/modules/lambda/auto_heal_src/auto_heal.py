# import json
# import os
# import urllib.request
# import boto3
# import pymysql
# import redis

# # Pull environment variables injected by Terraform
# RDS_HOST      = os.environ.get('RDS_HOST')
# RDS_USER      = os.environ.get('RDS_USER')
# SECRET_ARN    = os.environ.get('SECRET_ARN')
# VALKEY_HOST   = os.environ.get('VALKEY_HOST')
# SLACK_WEBHOOK = os.environ.get('SLACK_WEBHOOK')

# def get_db_password():
#     """Fetches the RDS password from AWS Secrets Manager securely."""
#     client = boto3.client('secretsmanager')
#     response = client.get_secret_value(SecretId=SECRET_ARN)
#     secret_dict = json.loads(response['SecretString'])
#     # Assuming your secret is stored with the key 'password'
#     return secret_dict.get('password')

# def send_slack_alert(message):
#     """Sends a formatted SRE alert to Slack using native Python libraries."""
#     slack_body = {
#         'text': f"🛠️ *Tier 3 Auto-Healer Activated* 🛠️\n{message}"
#     }
#     req = urllib.request.Request(
#         SLACK_WEBHOOK, 
#         data=json.dumps(slack_body).encode('utf-8'), 
#         headers={'Content-Type': 'application/json'},
#         method='POST'
#     )
#     try:
#         urllib.request.urlopen(req, timeout=5)
#     except Exception as e:
#         print(f"Failed to send Slack alert: {e}")

# def handler(event, context):
#     print("Auto-Healer Lambda invoked by EventBridge.")
#     actions_taken = []
    
#     try:
#         # 1. Fetch the Database Password
#         password = get_db_password()
        
#         # 2. Connect to the RDS Database
#         print(f"Connecting to RDS at {RDS_HOST}...")
#         connection = pymysql.connect(
#             host=RDS_HOST,
#             user=RDS_USER,
#             password=password,
#             connect_timeout=5,
#             cursorclass=pymysql.cursors.DictCursor
#         )
        
#         # 3. Hunt and Kill Hanging Queries
#         with connection.cursor() as cursor:
#             # Find any query running for 30 seconds or longer
#             sql = """
#                 SELECT ID, USER, TIME, STATE, INFO 
#                 FROM information_schema.processlist 
#                 WHERE command = 'Query' AND time >= 30;
#             """
#             cursor.execute(sql)
#             bad_queries = cursor.fetchall()
            
#             if bad_queries:
#                 for q in bad_queries:
#                     query_id = q['ID']
#                     info = q['INFO'] or "Unknown Query"
#                     # Execute the kill command
#                     cursor.execute(f"KILL {query_id}")
#                     actions_taken.append(f"Killed Query ID {query_id} (Running for {q['TIME']}s): `{info[:50]}...`")
#             else:
#                 actions_taken.append("No isolated long-running queries found. Checking connection saturation.")
        
#         connection.close()
        
#         # 4. Flush Valkey (Redis) Cache
#         # We do this to ensure no poisoned cache data is causing a database stampede
#         print(f"Connecting to Valkey at {VALKEY_HOST}...")
#         cache = redis.Redis(host=VALKEY_HOST, port=6379, decode_responses=True, socket_timeout=3)
#         cache.flushall()
#         actions_taken.append("Flushed Valkey object cache to clear poisoned state and reset connections.")
        
#         # 5. Report Success to Slack
#         report = "\n".join(f"• {action}" for action in actions_taken)
#         send_slack_alert(f"Incident mitigated successfully. Actions taken:\n{report}")
        
#         return {
#             'statusCode': 200,
#             'body': json.dumps('Heal successful')
#         }
        
#     except Exception as e:
#         error_msg = f"Auto-heal script failed during execution: {str(e)}"
#         print(error_msg)
#         send_slack_alert(error_msg)
#         raise e

import json
import os
import urllib.request
import boto3
import pymysql
import redis

# Pull environment variables injected by Terraform
RDS_HOST      = os.environ.get('RDS_HOST')
RDS_USER      = os.environ.get('RDS_USER')
SECRET_ARN    = os.environ.get('SECRET_ARN')
VALKEY_HOST   = os.environ.get('VALKEY_HOST')
SLACK_WEBHOOK = os.environ.get('SLACK_WEBHOOK')

def get_db_password():
    """Fetches the RDS password from AWS Secrets Manager securely."""
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=SECRET_ARN)
    secret_string = response['SecretString']
    
    try:
        # Try to parse it as a JSON dictionary (Standard AWS format)
        secret_dict = json.loads(secret_string)
        # Check common key names AWS uses
        return secret_dict.get('password') or secret_dict.get('password_key')
    except json.JSONDecodeError:
        # If it's NOT JSON, assume the string itself is the raw password!
        print("Secret is not JSON. Using raw string as password.")
        return secret_string

def send_slack_alert(message):
    """Sends a formatted SRE alert to Slack using native Python libraries."""
    slack_body = {
        'text': f"🛠️ *Tier 3 Auto-Healer Activated* 🛠️\n{message}"
    }
    req = urllib.request.Request(
        SLACK_WEBHOOK, 
        data=json.dumps(slack_body).encode('utf-8'), 
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        print(f"Failed to send Slack alert: {e}")

def handler(event, context):
    print("Auto-Healer Lambda invoked by EventBridge.")
    actions_taken = []
    
    try:
        # 1. Fetch the Database Password
        password = get_db_password()
        
        # 2. Connect to the RDS Database
        print(f"Connecting to RDS at {RDS_HOST}...")
        connection = pymysql.connect(
            host=RDS_HOST,
            user=RDS_USER,
            password=password,
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor
        )
        
        # 3. Hunt and Kill Hanging Queries
        with connection.cursor() as cursor:
            # Find any query running for 30 seconds or longer
            sql = """
                SELECT ID, USER, TIME, STATE, INFO 
                FROM information_schema.processlist 
                WHERE command = 'Query' AND time >= 30;
            """
            cursor.execute(sql)
            bad_queries = cursor.fetchall()
            
            if bad_queries:
                for q in bad_queries:
                    query_id = q['ID']
                    info = q['INFO'] or "Unknown Query"
                    # Execute the kill command
                    cursor.execute(f"KILL {query_id}")
                    actions_taken.append(f"Killed Query ID {query_id} (Running for {q['TIME']}s): `{info[:50]}...`")
            else:
                actions_taken.append("No isolated long-running queries found. Checking connection saturation.")
        
        connection.close()
        
        # 4. Flush Valkey (Redis) Cache
        # We do this to ensure no poisoned cache data is causing a database stampede
        print(f"Connecting to Valkey at {VALKEY_HOST}...")
        cache = redis.Redis(host=VALKEY_HOST, port=6379, decode_responses=True, socket_timeout=3)
        cache.flushall()
        actions_taken.append("Flushed Valkey object cache to clear poisoned state and reset connections.")
        
        # 5. Report Success to Slack
        report = "\n".join(f"• {action}" for action in actions_taken)
        send_slack_alert(f"Incident mitigated successfully. Actions taken:\n{report}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Heal successful')
        }
        
    except Exception as e:
        error_msg = f"Auto-heal script failed during execution: {str(e)}"
        print(error_msg)
        send_slack_alert(error_msg)
        raise e