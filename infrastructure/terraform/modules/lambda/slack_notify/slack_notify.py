# import json, os, requests

# # Pull the environment variables injected by Terraform
# SLACK_WEBHOOK = os.environ['SLACK_WEBHOOK']
# GRAFANA_URL   = os.environ['GRAFANA_URL']

# def handler(event, context):
#     # Read the data sent by the SNS Topic
#     sns = event['Records'][0]['Sns']
#     message = json.loads(sns['Message'])

#     alarm_name = message.get('AlarmName', 'Unknown Alarm')
#     state      = message.get('NewStateValue', 'UNKNOWN')
#     reason     = message.get('NewStateReason', 'No reason provided')[:300]

#     # Extract the client_id (e.g., HIGH-client3-latency -> client3)
#     parts = alarm_name.split('-')
#     severity  = parts[0] if parts else 'UNKNOWN'
#     client_id = parts[1] if len(parts) > 1 else 'platform'

#     # Set colors based on severity
#     if severity == 'CRITICAL':
#         color, icon = 'danger', '🚨'
#     elif severity == 'HIGH':
#         color, icon = 'warning', '⚠️'
#     else:
#         color, icon = '#439FE0', 'ℹ️'

#     # The SRE Magic: Build a clickable link that opens Grafana directly to the broken client
#     grafana_link = f'{GRAFANA_URL}?var-client={client_id}&from=now-3h&to=now'

#     slack_body = {
#         'attachments': [{
#             'color': color if state == 'ALARM' else 'good',
#             'title': f'{icon} {alarm_name}',
#             'fields': [
#                 {'title': 'Client',  'value': client_id, 'short': True},
#                 {'title': 'State',   'value': state,     'short': True},
#                 {'title': 'Reason',  'value': reason,    'short': False},
#                 {'title': 'Grafana', 'value': f'<{grafana_link}|Open dashboard for {client_id}>', 'short': False},
#             ],
#             'footer': 'WordPress SRE Platform',
#         }]
#     }

#     # Send the message to Slack
#     requests.post(SLACK_WEBHOOK, json=slack_body, timeout=5)
#     return {'status': 'sent', 'alarm': alarm_name}

# import json, os, requests

# # Pull the environment variables injected by Terraform
# SLACK_WEBHOOK = os.environ['SLACK_WEBHOOK']
# GRAFANA_URL   = os.environ['GRAFANA_URL']

# def handler(event, context):
#     # Read the data sent by the SNS Topic
#     sns = event['Records'][0]['Sns']
#     message = json.loads(sns['Message'])

#     alarm_name = message.get('AlarmName', 'Unknown Alarm')
#     state      = message.get('NewStateValue', 'UNKNOWN')
#     reason     = message.get('NewStateReason', 'No reason provided')[:300]

#     # Extract the client_id (e.g., HIGH-client3-latency -> client3)
#     parts = alarm_name.split('-')
#     severity  = parts[0] if parts else 'UNKNOWN'
#     client_id = parts[1] if len(parts) > 1 else 'platform'

#     # Set colors based on severity
#     if severity == 'CRITICAL':
#         color, icon = 'danger', '🚨'
#     elif severity == 'HIGH':
#         color, icon = 'warning', '⚠️'
#     else:
#         color, icon = '#439FE0', 'ℹ️'

#     # The SRE Magic: Build a clickable link that opens Grafana directly to the broken client
#     grafana_link = f'{GRAFANA_URL}?var-client={client_id}&from=now-3h&to=now'

#     slack_body = {
#         'attachments': [{
#             'color': color if state == 'ALARM' else 'good',
#             'title': f'{icon} {alarm_name}',
#             'fields': [
#                 {'title': 'Client',  'value': client_id, 'short': True},
#                 {'title': 'State',   'value': state,     'short': True},
#                 {'title': 'Reason',  'value': reason,    'short': False},
#                 {'title': 'Grafana', 'value': f'<{grafana_link}|Open dashboard for {client_id}>', 'short': False},
#             ],
#             'footer': 'WordPress SRE Platform',
#         }]
#     }

#     # Send the message to Slack
#     requests.post(SLACK_WEBHOOK, json=slack_body, timeout=5)
#     return {'status': 'sent', 'alarm': alarm_name}

import json
import os
import urllib.request
import urllib.error

# Pull the environment variables injected by Terraform
SLACK_WEBHOOK = os.environ['SLACK_WEBHOOK']
GRAFANA_URL   = os.environ['GRAFANA_URL']

def handler(event, context):
    # Read the data sent by the SNS Topic
    try:
        sns = event['Records'][0]['Sns']
        message = json.loads(sns['Message'])
    except (KeyError, json.JSONDecodeError, TypeError) as e:
        print(f"Error parsing SNS event: {e}")
        return {'status': 'error', 'message': 'Invalid event format'}

    alarm_name = message.get('AlarmName', 'Unknown Alarm')
    state      = message.get('NewStateValue', 'UNKNOWN')
    reason     = message.get('NewStateReason', 'No reason provided')[:300]

    # Extract the client_id (e.g., HIGH-client3-latency -> client3)
    parts = alarm_name.split('-')
    severity  = parts[0] if parts else 'UNKNOWN'
    client_id = parts[1] if len(parts) > 1 else 'platform'

    # Set colors based on severity
    if severity == 'CRITICAL':
        color, icon = 'danger', '🚨'
    elif severity == 'HIGH':
        color, icon = 'warning', '⚠️'
    else:
        color, icon = '#439FE0', 'ℹ️'

    # The SRE Magic: Build a clickable link that opens Grafana directly to the broken client
    grafana_link = f'{GRAFANA_URL}?var-client={client_id}&from=now-3h&to=now'

    slack_body = {
        'attachments': [{
            'color': color if state == 'ALARM' else 'good',
            'title': f'{icon} {alarm_name}',
            'fields': [
                {'title': 'Client',  'value': client_id, 'short': True},
                {'title': 'State',   'value': state,     'short': True},
                {'title': 'Reason',  'value': reason,    'short': False},
                {'title': 'Grafana', 'value': f'<{grafana_link}|Open dashboard for {client_id}>', 'short': False},
            ],
            'footer': 'WordPress SRE Platform',
        }]
    }

    # Send the message to Slack using built-in urllib (No external dependencies needed!)
    req = urllib.request.Request(
        SLACK_WEBHOOK, 
        data=json.dumps(slack_body).encode('utf-8'), 
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            print(f"Slack message sent successfully. HTTP Status: {response.status}")
            return {'status': 'sent', 'alarm': alarm_name}
    except urllib.error.URLError as e:
        print(f"Failed to send message to Slack: {e}")
        return {'status': 'error', 'alarm': alarm_name, 'reason': str(e)}