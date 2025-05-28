#!/usr/bin/env python3
"""
Automated Arbitrage Bot for KyberSwap <-> Larry DEX
Runs continuously, checking for profitable arbitrage opportunities every 30 seconds
Uses 0.002 ETH per trade as requested
"""

import asyncio
import aiohttp
import json
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
CONTRACT_ADDRESS = "0xC14957db5A544167633cF8B480eB6FbB25b6da19"
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
TRADE_AMOUNT_ETH = "0.002"
TRADE_AMOUNT_WEI = Web3.to_wei(TRADE_AMOUNT_ETH, 'ether')
MIN_PROFIT_PERCENTAGE = 0.5  # Minimum 0.5% profit to execute trade

# Token addresses
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
LARRY_ADDRESS = "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888"

# Contract ABI (minimal for our needs)
CONTRACT_ABI = [
    {
        "inputs": [
            {"name": "swapData", "type": "bytes"},
            {"name": "minReturnAmount", "type": "uint256"},
            {"name": "direction", "type": "bool"}
        ],
        "name": "executeArbitrageWithSwapData",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    }
]

# Larry DEX ABI for price calculations
LARRY_DEX_ABI = [
    {
        "inputs": [{"name": "value", "type": "uint256"}],
        "name": "LARRYtoETH",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"name": "amount", "type": "uint256"}],
        "name": "getBuyLARRY",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ArbitrageBot:
    def __init__(self):
        if not PRIVATE_KEY:
            raise ValueError("PRIVATE_KEY not found in .env file")
        
        self.w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self.account = self.w3.eth.account.from_key(PRIVATE_KEY)
        self.contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(CONTRACT_ADDRESS),
            abi=CONTRACT_ABI
        )
        self.larry_contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(LARRY_ADDRESS),
            abi=LARRY_DEX_ABI
        )
        logger.info(f"Bot initialized for account: {self.account.address}")
        logger.info(f"Contract address: {CONTRACT_ADDRESS}")
        logger.info(f"Trade amount: {TRADE_AMOUNT_ETH} ETH")

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
            deadline = int(time.time()) + 3600  # 1 hour from now
            
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

    def get_larry_price_out(self, larry_amount):
        """Calculate ETH output from Larry DEX (bonding curve)"""
        try:
            # Call Larry DEX directly to get Larry -> ETH conversion
            eth_out = self.larry_contract.functions.LARRYtoETH(larry_amount).call()
            return eth_out
        except Exception as e:
            logger.error(f"Error getting Larry price: {e}")
            return 0
    
    def get_larry_from_eth(self, eth_amount):
        """Calculate LARRY amount from ETH via Larry DEX"""
        try:
            # Call Larry DEX to get ETH -> LARRY conversion
            larry_out = self.larry_contract.functions.getBuyLARRY(eth_amount).call()
            return larry_out
        except Exception as e:
            logger.error(f"Error getting LARRY from ETH: {e}")
            return 0

    def calculate_profit_percentage(self, input_amount, output_amount):
        """Calculate profit percentage"""
        if input_amount == 0:
            return 0
        return ((output_amount - input_amount) / input_amount) * 100

    async def check_both_arbitrage_directions(self, session):
        """Check arbitrage opportunities in both directions"""
        try:
            best_route = None
            best_profit = 0
            best_direction = True
            
            # Direction 1: ETH -> LARRY (KyberSwap) -> ETH (Larry)
            route_1 = await self.get_kyberswap_route(
                session, ETH_ADDRESS, LARRY_ADDRESS, TRADE_AMOUNT_WEI
            )
            
            if route_1 and route_1.get('routeSummary'):
                larry_amount = int(route_1['routeSummary']['amountOut'])
                larry_amount_after_slippage = larry_amount * 999 // 1000  # 0.1% slippage
                eth_out = self.get_larry_price_out(larry_amount_after_slippage)
                profit_pct_1 = self.calculate_profit_percentage(TRADE_AMOUNT_WEI, eth_out)
                
                logger.info(f"Direction 1 - ETH->LARRY(Kyber)->ETH(Larry): {TRADE_AMOUNT_ETH} ETH -> {larry_amount/1e18:.6f} LARRY -> {eth_out/1e18:.6f} ETH (Profit: {profit_pct_1:.2f}%)")
                
                if profit_pct_1 >= MIN_PROFIT_PERCENTAGE and profit_pct_1 > best_profit:
                    best_route = route_1['routeSummary']
                    best_profit = profit_pct_1
                    best_direction = True
            
            # Direction 2: ETH -> LARRY (Larry) -> ETH (KyberSwap)
            try:
                # Get how much LARRY we'd get from Larry DEX
                larry_from_larry_dex = self.get_larry_from_eth(TRADE_AMOUNT_WEI)
                
                if larry_from_larry_dex > 0:
                    # Check what we'd get selling this LARRY on KyberSwap
                    route_2 = await self.get_kyberswap_route(
                        session, LARRY_ADDRESS, ETH_ADDRESS, larry_from_larry_dex
                    )
                    
                    if route_2 and route_2.get('routeSummary'):
                        eth_out_kyber = int(route_2['routeSummary']['amountOut'])
                        eth_out_after_slippage = eth_out_kyber * 999 // 1000  # 0.1% slippage
                        profit_pct_2 = self.calculate_profit_percentage(TRADE_AMOUNT_WEI, eth_out_after_slippage)
                        
                        logger.info(f"Direction 2 - ETH->LARRY(Larry)->ETH(Kyber): {TRADE_AMOUNT_ETH} ETH -> {larry_from_larry_dex/1e18:.6f} LARRY -> {eth_out_after_slippage/1e18:.6f} ETH (Profit: {profit_pct_2:.2f}%)")
                        
                        if profit_pct_2 >= MIN_PROFIT_PERCENTAGE and profit_pct_2 > best_profit:
                            best_route = route_2['routeSummary']
                            best_profit = profit_pct_2
                            best_direction = False
            except Exception as e:
                logger.debug(f"Direction 2 check failed: {e}")
            
            if best_route and best_profit >= MIN_PROFIT_PERCENTAGE:
                direction_name = "ETH->LARRY(Kyber)->ETH(Larry)" if best_direction else "ETH->LARRY(Larry)->ETH(Kyber)"
                logger.info(f"🎯 Best opportunity: {direction_name} with {best_profit:.2f}% profit")
                return best_route, best_profit, best_direction
            else:
                logger.info("⏳ No profitable opportunities found in either direction")
                return None, 0, True
                
        except Exception as e:
            logger.error(f"Error checking arbitrage opportunities: {e}")
            return None, 0, True

    async def execute_arbitrage(self, route_summary, direction):
        """Execute arbitrage trade"""
        try:
            async with aiohttp.ClientSession() as session:
                # Build swap data
                swap_data_response = await self.build_kyberswap_swap(session, route_summary)
                
                if not swap_data_response or not swap_data_response.get('data'):
                    logger.error("Failed to build swap data")
                    return False
                
                swap_data = swap_data_response['data']
                
                # Validate swap data
                if not swap_data or len(swap_data) < 10:
                    logger.error("Invalid swap data received")
                    return False
                
                expected_larry = int(route_summary['amountOut'])
                min_return_larry = 1  # Set to 1 - let KyberSwap handle slippage
                
                logger.info(f"Expected LARRY: {expected_larry/1e18:.6f}, Min return set to: {min_return_larry}")
                
                # Prepare transaction
                nonce = self.w3.eth.get_transaction_count(self.account.address)
                gas_price = self.w3.eth.gas_price
                
                # Build transaction
                try:
                    logger.info(f"About to call contract with min_return_larry: {min_return_larry}")
                    txn = self.contract.functions.executeArbitrageWithSwapData(
                        bytes.fromhex(swap_data[2:]),  # Remove 0x prefix
                        min_return_larry,
                        direction
                    ).build_transaction({
                        'from': self.account.address,
                        'value': TRADE_AMOUNT_WEI,
                        'gas': 800000,  # Increased gas limit
                        'gasPrice': gas_price,
                        'nonce': nonce
                    })
                    
                    # Log the transaction data for debugging
                    logger.info(f"Transaction data: {txn.get('data', '')[:100]}...")
                    
                except Exception as e:
                    logger.error(f"Failed to build transaction: {e}")
                    return False
                
                # Sign and send transaction
                signed_txn = self.w3.eth.account.sign_transaction(txn, PRIVATE_KEY)
                tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)
                
                logger.info(f"Transaction sent: {tx_hash.hex()}")
                
                # Wait for confirmation
                receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
                
                if receipt.status == 1:
                    logger.info(f"✅ Arbitrage executed successfully! Gas used: {receipt.gasUsed}")
                    return True
                else:
                    logger.error(f"❌ Transaction failed - Receipt: {receipt}")
                    return False
                    
        except Exception as e:
            logger.error(f"Error executing arbitrage: {e}")
            return False

    async def run_monitoring_loop(self):
        """Main monitoring loop"""
        logger.info("🚀 Starting arbitrage monitoring...")
        
        while True:
            try:
                async with aiohttp.ClientSession() as session:
                    # Check both directions for arbitrage opportunities
                    route_summary, profit_pct, direction = await self.check_both_arbitrage_directions(session)
                    
                    if route_summary and profit_pct >= MIN_PROFIT_PERCENTAGE:
                        direction_name = "ETH->LARRY(Kyber)->ETH(Larry)" if direction else "ETH->LARRY(Larry)->ETH(Kyber)"
                        logger.info(f"🎯 Executing {direction_name} arbitrage with {profit_pct:.2f}% profit")
                        
                        success = await self.execute_arbitrage(route_summary, direction)
                        
                        if success:
                            logger.info("💰 Arbitrage completed successfully!")
                        else:
                            logger.error("❌ Arbitrage execution failed")
                    else:
                        logger.info("⏳ No profitable opportunities found in either direction")
                
                # Wait 30 seconds before next check
                await asyncio.sleep(30)
                
            except KeyboardInterrupt:
                logger.info("🛑 Bot stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(30)

async def main():
    """Main entry point"""
    bot = ArbitrageBot()
    
    # Check account balance
    balance = bot.w3.eth.get_balance(bot.account.address)
    balance_eth = bot.w3.from_wei(balance, 'ether')
    
    if balance_eth < Decimal(TRADE_AMOUNT_ETH):
        logger.error(f"Insufficient balance: {balance_eth} ETH (need at least {TRADE_AMOUNT_ETH} ETH)")
        return
    
    logger.info(f"Account balance: {balance_eth} ETH")
    
    await bot.run_monitoring_loop()

if __name__ == "__main__":
    asyncio.run(main())