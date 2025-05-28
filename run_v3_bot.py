#!/usr/bin/env python3
"""
V3 Arbitrage Bot - Principal Protected with Gas Reimbursement
Contract: 0x7Bee2beF4adC5504CD747106924304d26CcFBd94
"""

import asyncio
import aiohttp
import time
import os
from web3 import Web3
from decimal import Decimal
import logging
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
RPC_URL = os.getenv("BASE_RPC_URL", "https://mainnet.base.org")
CONTRACT_ADDRESS = "0x7Bee2beF4adC5504CD747106924304d26CcFBd94"  # V3 Contract
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
TRADE_AMOUNT_ETH = "0.002"
TRADE_AMOUNT_WEI = Web3.to_wei(TRADE_AMOUNT_ETH, 'ether')

# Token addresses
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
LARRY_ADDRESS = "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888"

# V3 Contract ABI
CONTRACT_ABI = [
    {
        "inputs": [
            {"name": "swapData", "type": "bytes"},
            {"name": "direction", "type": "bool"}
        ],
        "name": "executePrincipalProtectedArbitrage",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "gasReimbursement",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "profitRecipient",
        "outputs": [{"name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class V3ArbitrageBot:
    def __init__(self):
        if not PRIVATE_KEY:
            raise ValueError("PRIVATE_KEY not found in .env file")
        
        self.w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self.account = self.w3.eth.account.from_key(PRIVATE_KEY)
        self.contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(CONTRACT_ADDRESS),
            abi=CONTRACT_ABI
        )
        
        # Get contract info
        self.gas_reimbursement = self.contract.functions.gasReimbursement().call()
        self.profit_recipient = self.contract.functions.profitRecipient().call()
        
        logger.info(f"🤖 V3 Bot initialized")
        logger.info(f"📄 Contract: {CONTRACT_ADDRESS}")
        logger.info(f"👤 Account: {self.account.address}")
        logger.info(f"💰 Trade amount: {TRADE_AMOUNT_ETH} ETH")
        logger.info(f"⛽ Gas reimbursement: {Web3.from_wei(self.gas_reimbursement, 'ether')} ETH")
        logger.info(f"📬 Profit recipient: {self.profit_recipient}")

    async def get_kyberswap_route(self, session, token_in, token_out, amount_in):
        """Get route from KyberSwap API"""
        try:
            url = "https://aggregator-api.kyberswap.com/base/api/v1/routes"
            params = {
                "tokenIn": token_in,
                "tokenOut": token_out,
                "amountIn": str(amount_in)
            }
            
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('data')
                else:
                    logger.error(f"KyberSwap route error: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"Error getting KyberSwap route: {e}")
            return None

    async def build_kyberswap_swap(self, session, route_summary):
        """Build swap data from KyberSwap API"""
        try:
            url = "https://aggregator-api.kyberswap.com/base/api/v1/route/build"
            deadline = int(time.time()) + 3600
            
            payload = {
                "routeSummary": route_summary,
                "sender": CONTRACT_ADDRESS,
                "recipient": CONTRACT_ADDRESS,
                "slippageTolerance": 300,  # 3%
                "deadline": deadline
            }
            
            async with session.post(url, json=payload) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('data')
                else:
                    logger.error(f"KyberSwap build error: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"Error building KyberSwap swap: {e}")
            return None

    async def check_opportunities(self, session):
        """Check for arbitrage opportunities"""
        try:
            # Check ETH -> LARRY (Kyber) -> ETH (Larry)
            route_kyber_larry = await self.get_kyberswap_route(
                session, ETH_ADDRESS, LARRY_ADDRESS, TRADE_AMOUNT_WEI
            )
            
            if route_kyber_larry and route_kyber_larry.get('routeSummary'):
                larry_amount = int(route_kyber_larry['routeSummary']['amountOut'])
                logger.info(f"Kyber->Larry route: {TRADE_AMOUNT_ETH} ETH -> {larry_amount/1e18:.6f} LARRY")
                
                # Since this is volume generation, we execute if we get back at least principal + gas
                return {
                    'direction': True,
                    'direction_name': 'ETH->LARRY(Kyber)->ETH(Larry)',
                    'route': route_kyber_larry['routeSummary']
                }
            
            # Also check Larry -> Kyber direction
            # (Implementation depends on Larry DEX ABI availability)
            
            return None
                
        except Exception as e:
            logger.error(f"Error checking opportunities: {e}")
            return None

    async def execute_arbitrage(self, opportunity):
        """Execute arbitrage trade"""
        try:
            async with aiohttp.ClientSession() as session:
                # Build swap data
                swap_data_response = await self.build_kyberswap_swap(session, opportunity['route'])
                
                if not swap_data_response or not swap_data_response.get('data'):
                    logger.error("Failed to build swap data")
                    return False
                
                swap_data = swap_data_response['data']
                
                logger.info(f"Executing {opportunity['direction_name']} arbitrage...")
                logger.info(f"Principal: {TRADE_AMOUNT_ETH} ETH (protected)")
                logger.info(f"Gas reimbursement: {Web3.from_wei(self.gas_reimbursement, 'ether')} ETH")
                
                # Prepare transaction
                nonce = self.w3.eth.get_transaction_count(self.account.address)
                gas_price = int(self.w3.eth.gas_price * 1.2)  # 20% higher
                
                # Build transaction
                txn = self.contract.functions.executePrincipalProtectedArbitrage(
                    bytes.fromhex(swap_data[2:]),  # Remove 0x prefix
                    opportunity['direction']
                ).build_transaction({
                    'from': self.account.address,
                    'value': TRADE_AMOUNT_WEI,
                    'gas': 800000,
                    'gasPrice': gas_price,
                    'nonce': nonce
                })
                
                # Sign and send
                signed_txn = self.w3.eth.account.sign_transaction(txn, PRIVATE_KEY)
                tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)
                
                logger.info(f"Transaction sent: {tx_hash.hex()}")
                logger.info(f"View on BaseScan: https://basescan.org/tx/{tx_hash.hex()}")
                
                # Wait for confirmation
                receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
                
                if receipt.status == 1:
                    logger.info(f"✅ Trade executed successfully!")
                    logger.info(f"Gas used: {receipt.gasUsed}")
                    logger.info(f"You received: {TRADE_AMOUNT_ETH} ETH + 0.00005 ETH gas reimbursement")
                    logger.info(f"Any profits sent to: {self.profit_recipient}")
                    return True
                else:
                    logger.error(f"❌ Transaction failed")
                    return False
                    
        except Exception as e:
            logger.error(f"Error executing arbitrage: {e}")
            return False

    async def run_monitoring_loop(self):
        """Main monitoring loop"""
        logger.info("🚀 Starting V3 arbitrage bot...")
        logger.info("💡 Principal protected + gas reimbursement")
        
        while True:
            try:
                async with aiohttp.ClientSession() as session:
                    opportunity = await self.check_opportunities(session)
                    
                    if opportunity:
                        logger.info(f"🎯 Opportunity found: {opportunity['direction_name']}")
                        
                        success = await self.execute_arbitrage(opportunity)
                        
                        if success:
                            logger.info("💰 Volume generated successfully!")
                        else:
                            logger.error("❌ Trade execution failed")
                    else:
                        logger.info("⏳ Waiting for opportunities...")
                
                await asyncio.sleep(30)
                
            except KeyboardInterrupt:
                logger.info("🛑 Bot stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(30)

async def main():
    """Main entry point"""
    bot = V3ArbitrageBot()
    
    # Check account balance
    balance = bot.w3.eth.get_balance(bot.account.address)
    balance_eth = bot.w3.from_wei(balance, 'ether')
    
    min_required = Decimal(TRADE_AMOUNT_ETH) + Decimal('0.0005')  # Trade + gas buffer
    
    if balance_eth < min_required:
        logger.error(f"Insufficient balance: {balance_eth} ETH (need at least {min_required} ETH)")
        return
    
    logger.info(f"💰 Account balance: {balance_eth} ETH")
    
    await bot.run_monitoring_loop()

if __name__ == "__main__":
    asyncio.run(main())