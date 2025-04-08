import boto3
import pymysql
import json

def get_db_credentials(secret_name, region_name="us-east-1"):
    client = boto3.client("secretsmanager", region_name=region_name)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

def lambda_handler(event, context):
    secret_name = "dev/lambda-db"  # Replace with your actual secret name
    region = "us-east-1"
    new_db = "new_sample_db"
    table_name = "users"
    
    # Get credentials
    creds = get_db_credentials(secret_name, region)

    try:
        # Connect without specifying DB to create new one
        connection = pymysql.connect(
            host=creds['host'],
            user=creds['username'],
            password=creds['password'],
            port=int(creds['port']),
            connect_timeout=5
        )
        with connection.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS {new_db};")
        connection.commit()
        connection.close()

        # Now connect to the new DB
        connection = pymysql.connect(
            host=creds['host'],
            user=creds['username'],
            password=creds['password'],
            db=new_db,
            port=int(creds['port']),
            connect_timeout=5
        )

        with connection.cursor() as cursor:
            # Create table
            cursor.execute(f"""
                CREATE TABLE IF NOT EXISTS {table_name} (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100),
                    email VARCHAR(100)
                );
            """)
            
            # Insert a row
            cursor.execute(f"""
                INSERT INTO {table_name} (name, email)
                VALUES (%s, %s);
            """, ("Jane Doe", "jane.doe@example.com"))
        
        connection.commit()
        return {
            'statusCode': 200,
            'body': json.dumps(f"Database `{new_db}` and table `{table_name}` created. Data inserted successfully.")
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {str(e)}")
        }

    finally:
        if connection:
            connection.close()

