import boto3
from datetime import datetime, timedelta, timezone

def lambda_handler(event, context):
    # Initialize a session using Amazon S3
    s3 = boto3.client('s3')
    current_time = datetime.now(timezone.utc)
    cutoff_time = current_time - timedelta(days=30)
    # List all buckets
    response = s3.list_buckets()
    # Initialize a list to hold bucket names created before the cutoff time
    empty_buckets = []
    # Iterate over all buckets and check their creation dates
    for bucket in response['Buckets']:
        bucket_name = bucket['Name']
        creation_date = bucket['CreationDate']
        # Check if the creation date is before the cutoff time
        if creation_date < cutoff_time:
            try:
                response = s3.list_objects_v2(Bucket=bucket_name, MaxKeys=1)
                if 'Contents' not in response:
                    empty_buckets.append(bucket_name)                   
            except:
                pass

    # # Return the list of old buckets
    return {
        'statusCode': 200,
        'emptyBuckets': empty_buckets,
    }



