import boto3, os , json
import redis 
import pymysql
import requests

VALKEY_HOST = os.environ['VALKEY_HOST']
RDS_HOST = os.environ['RDS_HOST']
RDS_USER      = os.environ['RDS_USER']
# RDS_PASS      = os.environ['RDS_PASS']
SLACK_WEBHOOK = os.environ['SLACK_WEBHOOK']

def get_db_password():
    client = boto3.client('secretsmanager') # Region is auto-detected in Lambda
    response = client.get_secret_value(SecretId=SECRET_ARN)
    # Assuming your secret is stored as JSON like {"password": "your-password"}
    secret_dict = json.loads(response['SecretString'])
    return secret_dict['password']

def handler (event,context):
    alarm_name= event.get('detail' , {}).get('alarmName','')
    parts = alarm_name.split('-')
    if len(parts) < 2:
        return {"status": "ignored"}
    client_id= parts[1]
    print(f"Auto-healing triggered for: {client_id}")
    action_taken = []
    
    # valkey cluster 
    try:
        valkey = redis.Redis(host=VALKEY_HOST, port=6379, decode_responses=True)
        client_keys = valkey.keys(f'{client_id}_wp_*')
        if len(client_keys) > 5000:
            valkey.delete(*client_keys)
            actions_taken.append(f"Cleared {len(client_keys)} Valkey cache keys.")
    except Exception as e:
        pass
    
    # mysql queries
    try:
        conn = pymysql.connect(host=RDS_HOST, user=RDS_USER, password=RDS_PASS, connect_timeout=5)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, time, info FROM information_schema.processlist "
            "WHERE db = %s AND time > 30 AND command != 'Sleep'",
            (f'wp_{client_id}',)
        )
        for query_id, duration, query_info in cursor.fetchall():
            cursor.execute(f"KILL {query_id}")
            actions_taken.append(f"Killed query {query_id} (running {duration}s).")
        conn.close()
    except Exception as e:
        pass
    
    ## slack 
    if actions_taken:
        message = {"attachments": [{"color": "warning", "title": f" AUTO-HEAL: {client_id}", "text": "\n".join(actions_taken)}]}
        try:
            requests.post(SLACK_WEBHOOK, json=message, timeout=5)
        except Exception:
            pass

    return {"status": "complete", "actions": actions_taken}