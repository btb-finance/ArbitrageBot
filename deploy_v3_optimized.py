#!/usr/bin/env python3
"""
Deploy V3 with optimized gas settings
"""

import os
import json
import time
from web3 import Web3
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
RPC_URL = os.getenv("BASE_RPC_URL", "https://mainnet.base.org")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
PROFIT_RECIPIENT = "0xfed2Ff614E0289D41937139730B49Ee158D02299"

# Read contract bytecode and ABI
try:
    with open("out/botv3.sol/ArbitrageLarryImprovedV2.json", "r") as f:
        contract_data = json.load(f)
        CONTRACT_BYTECODE = contract_data["bytecode"]["object"]
        CONTRACT_ABI = contract_data["abi"]
except:
    print("Contract not compiled. Please run: forge build src/botv3.sol")
    exit(1)

def deploy_v3_optimized():
    # Connect to Base
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = w3.eth.account.from_key(PRIVATE_KEY)
    
    print(f"Deploying V3 from account: {account.address}")
    balance = w3.eth.get_balance(account.address)
    print(f"Account balance: {w3.from_wei(balance, 'ether')} ETH")
    
    # Get current nonce
    current_nonce = w3.eth.get_transaction_count(account.address)
    print(f"Current nonce: {current_nonce}")
    
    # Create contract instance
    Contract = w3.eth.contract(abi=CONTRACT_ABI, bytecode=CONTRACT_BYTECODE)
    
    # Get current gas price and use reasonable multiplier
    base_gas_price = w3.eth.gas_price
    
    # Base mainnet typically has very low gas prices
    # Use 2x current price or minimum 0.1 gwei
    gas_price = max(base_gas_price * 2, Web3.to_wei(0.1, 'gwei'))
    
    print(f"Base gas price: {w3.from_wei(base_gas_price, 'gwei')} gwei")
    print(f"Using gas price: {w3.from_wei(gas_price, 'gwei')} gwei")
    
    # Estimate gas for deployment
    try:
        gas_estimate = Contract.constructor().estimate_gas({'from': account.address})
        gas_limit = int(gas_estimate * 1.2)  # 20% buffer
        print(f"Estimated gas: {gas_estimate}")
        print(f"Gas limit: {gas_limit}")
    except:
        gas_limit = 3600000  # Fallback gas limit
        print(f"Using fallback gas limit: {gas_limit}")
    
    # Calculate total cost
    total_cost = gas_limit * gas_price
    print(f"Estimated deployment cost: {w3.from_wei(total_cost, 'ether')} ETH")
    
    # Reserve some ETH for the setProfitRecipient transaction
    reserve_for_set = 100000 * gas_price  # Gas for setProfitRecipient
    total_needed = total_cost + reserve_for_set
    
    if balance < total_needed:
        print(f"\n⚠️ Balance might be tight")
        print(f"Have: {w3.from_wei(balance, 'ether')} ETH")
        print(f"Need: {w3.from_wei(total_needed, 'ether')} ETH (including reserve)")
        
        # Try with minimum gas price
        min_gas_price = Web3.to_wei(0.01, 'gwei')
        min_total = gas_limit * min_gas_price + reserve_for_set
        
        if balance >= min_total:
            print(f"\n✅ Can deploy with minimum gas price: {w3.from_wei(min_gas_price, 'gwei')} gwei")
            gas_price = min_gas_price
            total_cost = gas_limit * gas_price
        else:
            print(f"\n❌ Insufficient balance even with minimum gas")
            return None
    
    try:
        # Build deployment transaction
        deploy_txn = Contract.constructor().build_transaction({
            'from': account.address,
            'gas': gas_limit,
            'gasPrice': gas_price,
            'nonce': current_nonce,
            'chainId': 8453
        })
        
        print(f"\n🚀 Deploying V3 contract...")
        
        # Sign and send
        signed_txn = w3.eth.account.sign_transaction(deploy_txn, PRIVATE_KEY)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
        
        print(f"✅ Deployment transaction sent!")
        print(f"Transaction hash: {tx_hash.hex()}")
        print(f"View on BaseScan: https://basescan.org/tx/{tx_hash.hex()}")
        
        print("\nWaiting for confirmation...")
        
        # Wait for receipt
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)
        
        if receipt.status == 1:
            contract_address = receipt.contractAddress
            print(f"\n🎉 V3 CONTRACT DEPLOYED SUCCESSFULLY!")
            print(f"Contract address: {contract_address}")
            print(f"Gas used: {receipt.gasUsed}")
            print(f"Actual cost: {w3.from_wei(receipt.gasUsed * receipt.effectiveGasPrice, 'ether')} ETH")
            
            # Save address
            with open("V3_CONTRACT_ADDRESS.txt", "w") as f:
                f.write(f"V3 Contract Address: {contract_address}\n")
                f.write(f"Deployed at: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"Transaction: {tx_hash.hex()}\n")
                f.write(f"Block: {receipt.blockNumber}\n")
            
            # Set profit recipient
            print(f"\n📝 Setting profit recipient to: {PROFIT_RECIPIENT}")
            
            contract = w3.eth.contract(address=contract_address, abi=CONTRACT_ABI)
            
            # Check remaining balance
            remaining_balance = w3.eth.get_balance(account.address)
            print(f"Remaining balance: {w3.from_wei(remaining_balance, 'ether')} ETH")
            
            if remaining_balance > 50000 * gas_price:
                try:
                    set_nonce = current_nonce + 1
                    set_txn = contract.functions.setProfitRecipient(PROFIT_RECIPIENT).build_transaction({
                        'from': account.address,
                        'gas': 50000,
                        'gasPrice': gas_price,
                        'nonce': set_nonce,
                        'chainId': 8453
                    })
                    
                    signed_set = w3.eth.account.sign_transaction(set_txn, PRIVATE_KEY)
                    set_hash = w3.eth.send_raw_transaction(signed_set.raw_transaction)
                    
                    print(f"Set profit recipient tx: {set_hash.hex()}")
                    
                    try:
                        set_receipt = w3.eth.wait_for_transaction_receipt(set_hash, timeout=60)
                        if set_receipt.status == 1:
                            print("✅ Profit recipient set successfully!")
                            
                            # Verify final configuration
                            owner = contract.functions.owner().call()
                            recipient = contract.functions.profitRecipient().call()
                            gas_reimb = contract.functions.gasReimbursement().call()
                            
                            print(f"\n📊 V3 Contract Configuration:")
                            print(f"Address: {contract_address}")
                            print(f"Owner: {owner}")
                            print(f"Profit Recipient: {recipient}")
                            print(f"Gas Reimbursement: {w3.from_wei(gas_reimb, 'ether')} ETH")
                        else:
                            print("❌ Set profit recipient failed")
                    except:
                        print("⏳ Set profit recipient pending")
                        
                except Exception as e:
                    print(f"Could not set profit recipient: {e}")
                    print(f"\nSet it manually later:")
                    print(f'cast send {contract_address} "setProfitRecipient(address)" {PROFIT_RECIPIENT} --rpc-url {RPC_URL} --private-key $PRIVATE_KEY')
            else:
                print("\n⚠️ Insufficient balance to set profit recipient")
                print(f"Set it manually when you have more ETH:")
                print(f'cast send {contract_address} "setProfitRecipient(address)" {PROFIT_RECIPIENT} --rpc-url {RPC_URL} --private-key $PRIVATE_KEY')
            
            print(f"\n✅ V3 Bot Ready!")
            print(f"\nUpdate arbitrage_bot_v3.py with:")
            print(f'CONTRACT_ADDRESS = "{contract_address}"')
            
            # Update the bot file automatically
            try:
                with open("arbitrage_bot_v3.py", "r") as f:
                    content = f.read()
                
                # Replace the contract address
                old_line = 'CONTRACT_ADDRESS = "0xa5fb9aab6ee7a96a11c24caa68e83e8c73ec0b67"  # V2 Improved contract (V3 deployment stuck)'
                new_line = f'CONTRACT_ADDRESS = "{contract_address}"  # V3 deployed successfully!'
                
                content = content.replace(old_line, new_line)
                
                with open("arbitrage_bot_v3.py", "w") as f:
                    f.write(content)
                
                print("\n✅ Updated arbitrage_bot_v3.py with new contract address!")
            except:
                print("\n⚠️ Please manually update CONTRACT_ADDRESS in arbitrage_bot_v3.py")
            
            return contract_address
            
        else:
            print("❌ Deployment failed!")
            return None
            
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    if not PRIVATE_KEY:
        print("Error: PRIVATE_KEY not found in .env file")
    else:
        result = deploy_v3_optimized()
        
        if result:
            print(f"\n🎉 Success! V3 contract deployed at: {result}")
            print("\nRun your bot with:")
            print("python3 arbitrage_bot_v3.py")
        else:
            print("\n❌ Deployment failed")
            print("Check your balance or try again later")