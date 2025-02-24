# scripts/pull_from_dune.py
import os
import yaml
from dotenv import load_dotenv
import requests

def pull_queries():
    load_dotenv()
    api_key = os.getenv('DUNE_API_KEY')
    
    with open('queries.yml', 'r') as file:
        queries = yaml.safe_load(file)['queries']
    
    for query_id, description in queries.items():
        # API endpoint logic here
        print(f"Pulling query {query_id}: {description}")

if __name__ == "__main__":
    pull_queries()

# scripts/push_to_dune.py
import os
from dotenv import load_dotenv

def push_queries():
    load_dotenv()
    api_key = os.getenv('DUNE_API_KEY')
    
    queries_dir = 'queries'
    for file in os.listdir(queries_dir):
        if file.endswith('.sql'):
            query_id = file.split('___')[-1].replace('.sql', '')
            # API endpoint logic here
            print(f"Pushing query {query_id}")

if __name__ == "__main__":
    push_queries()

# scripts/preview_query.py
import sys
import os
from dotenv import load_dotenv

def preview_query(query_id):
    load_dotenv()
    api_key = os.getenv('DUNE_API_KEY')
    
    query_file = f'queries/query___{query_id}.sql'
    if os.path.exists(query_file):
        with open(query_file, 'r') as file:
            query = file.read()
            # API endpoint logic here
            print(f"Previewing query {query_id}")
    else:
        print(f"Query {query_id} not found")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python preview_query.py <query_id>")
    else:
        preview_query(sys.argv[1])

# scripts/upload_to_dune.py
import os
from dotenv import load_dotenv

def upload_csvs():
    load_dotenv()
    api_key = os.getenv('DUNE_API_KEY')
    
    uploads_dir = 'uploads'
    for file in os.listdir(uploads_dir):
        if file.endswith('.csv'):
            # API endpoint logic here
            print(f"Uploading {file}")

if __name__ == "__main__":
    upload_csvs()