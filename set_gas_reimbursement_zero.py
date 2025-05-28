#!/usr/bin/env python3
"""
Set gas reimbursement to 0 on the deployed V3 contract
"""

import json
from web3 import Web3
from eth_account import Account
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
RPC_URL = "https://mainnet.base.org"
PRIVATE_KEY = os.getenv('PRIVATE_KEY')
CONTRACT_ADDRESS = "0x7Bee2beF4adC5504CD747106924304d26CcFBd94"

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
account = Account.from_key(PRIVATE_KEY)

# Contract ABI (only the function we need)
ABI = json.loads('''[
    {
        "inputs": [{"internalType": "uint256","name": "_gasReimbursement","type": "uint256"}],
        "name": "setGasReimbursement",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]''')

# Initialize contract
contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=ABI)

def set_gas_reimbursement_to_zero():
    """Set gas reimbursement to 0"""
    print(f"Setting gas reimbursement to 0 on contract {CONTRACT_ADDRESS}...")
    
    try:
        # Get current nonce
        nonce = w3.eth.get_transaction_count(account.address)
        print(f"Current nonce: {nonce}")
        
        # Build transaction
        tx = contract.functions.setGasReimbursement(0).build_transaction({
            'from': account.address,
            'nonce': nonce,
            'gas': 100000,
            'gasPrice': w3.to_wei('0.1', 'gwei'),
            'chainId': 8453
        })
        
        # Sign and send transaction
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        
        print(f"Transaction sent: {tx_hash.hex()}")
        print("Waiting for confirmation...")
        
        # Wait for receipt
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)
        
        if receipt.status == 1:
            print(f"✅ Success! Gas reimbursement set to 0")
            print(f"Transaction hash: {receipt.transactionHash.hex()}")
            print(f"Gas used: {receipt.gasUsed}")
        else:
            print(f"❌ Transaction failed!")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    set_gas_reimbursement_to_zero()