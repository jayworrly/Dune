import os
import yaml
import requests
from dotenv import load_dotenv
import time

def get_query_content(query_id, api_key):
    headers = {
        'x-dune-api-key': api_key
    }
    
    # Dune API endpoint for getting query content
    url = f"https://api.dune.com/api/v1/query/{query_id}"
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        query_data = response.json()
        return query_data.get('query_sql', '')
    except requests.exceptions.RequestException as e:
        print(f"Error fetching query {query_id}: {str(e)}")
        return None

def pull_queries():
    load_dotenv()
    api_key = os.getenv('DUNE_API_KEY')
    
    if not api_key:
        print("Error: DUNE_API_KEY not found in .env file")
        return
    
    with open('queries.yml', 'r') as file:
        config = yaml.safe_load(file)
        queries = config['queries']
    
    # Create queries directory if it doesn't exist
    os.makedirs('queries', exist_ok=True)
    
    for query_id, description in queries.items():
        print(f"Pulling query {query_id}: {description}")
        
        query_content = get_query_content(query_id, api_key)
        if query_content:
            query_file = f'queries/query___{query_id}.sql'
            with open(query_file, 'w') as f:
                f.write(f"-- already part of a query repo\n")
                f.write(f"-- Query ID: {query_id}\n")
                f.write(f"-- Description: {description}\n\n")
                f.write(query_content)
            print(f"Successfully saved query {query_id}")
            # Add a small delay to avoid rate limiting
            time.sleep(1)
        else:
            print(f"Skipping query {query_id} due to error")

def main():
    print("Starting Dune Query Manager...")
    pull_queries()
    print("Query pull complete!")

if __name__ == "__main__":
    main()