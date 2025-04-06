import json
import requests

def handler(event, context):
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            sns_message = json.loads(body['Message'])

            if 'Records' in sns_message:
                for s3_event in sns_message['Records']:
                    bucket = s3_event['s3']['bucket']['name']
                    key = s3_event['s3']['object']['key']
                    print(f"New file uploaded: s3://{bucket}/{key}")
            else:
                print("SNS message does not contain S3 Records:", sns_message)
        except Exception as e:
            print("Error processing record:", e)
    
    return {'statusCode': 200}