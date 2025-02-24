from web3 import Web3
import psycopg2
import os
from dotenv import load_dotenv
from web3.middleware import geth_poa_middleware

# Connect to Avalanche C-Chain (Replace with your RPC endpoint)
AVAX_RPC_URL = "https://api.avax.network/ext/bc/C/rpc"  # Mainnet
# AVAX_RPC_URL = "https://api.avax-test.network/ext/bc/C/rpc"  # Testnet

w3 = Web3(Web3.HTTPProvider(AVAX_RPC_URL))

# Inject PoA Middleware
w3.middleware_onion.inject(geth_poa_middleware, layer=0)

# Check connection
if w3.is_connected():
    print("Connected to Avalanche C-Chain")
else:
    print("Failed to connect")

# PostgreSQL connection details (modify with your credentials)
conn = psycopg2.connect(
    dbname="dune_local",
    user="postgres",
    password="JJ+blue1014",
    host="localhost",
    port="5432"
)
cur = conn.cursor()

# Create a table if not exists
cur.execute("""
    CREATE TABLE IF NOT EXISTS transactions (
        hash TEXT PRIMARY KEY,
        block_number BIGINT,
        from_address TEXT,
        to_address TEXT,
        value NUMERIC,
        gas_price NUMERIC
    )
""")
conn.commit()

# Fetch latest block transactions
# List of target smart contract addresses
target_contracts = []


# Fetch latest block transactions
latest_block = w3.eth.get_block('latest', full_transactions=True)

for tx in latest_block.transactions:
    # Check if the transaction is directed to one of the target contracts
    if tx["to"] in target_contracts:
        cur.execute(""" 
            INSERT INTO transactions (hash, block_number, from_address, to_address, value, gas_price)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (hash) DO NOTHING
        """, (
            tx.hash.hex(),
            tx.blockNumber,
            tx["from"],
            tx["to"],
            w3.from_wei(tx["value"], 'Avax'),
            w3.from_wei(tx["gasPrice"], 'nAvax')
        ))

for tx in latest_block.transactions:
    cur.execute("""
        INSERT INTO transactions (hash, block_number, from_address, to_address, value, gas_price)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (hash) DO NOTHING
    """, (
        tx.hash.hex(),
        tx.blockNumber,
        tx["from"],
        tx["to"],
        w3.from_wei(tx["value"], 'ether'),
        w3.from_wei(tx["gasPrice"], 'gwei')
    ))

conn.commit()
cur.close()
conn.close()

print("Latest transactions stored in PostgreSQL")
