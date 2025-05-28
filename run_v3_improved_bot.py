#!/usr/bin/env python3
"""
V3 Enhanced Arbitrage Bot - Optimized Performance & Reliability
Features:
- Parallel opportunity checking for faster detection
- Binary search for optimal amount finding
- Cached DEX state to reduce RPC calls
- Advanced gas management
- Comprehensive error handling and retry logic
- MEV protection considerations
"""

import asyncio
import aiohttp
import time
import os
from web3 import Web3
from decimal import Decimal
import logging
from dotenv import load_dotenv
import json
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from collections import deque
from datetime import datetime, timedelta
import statistics

# Load environment variables
load_dotenv()

# Configuration
RPC_URL = os.getenv("BASE_RPC_URL", "https://mainnet.base.org")
CONTRACT_ADDRESS = "0x7Bee2beF4adC5504CD747106924304d26CcFBd94"
PRIVATE_KEY = os.getenv("PRIVATE_KEY")

# Token addresses
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
LARRY_ADDRESS = "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888"

# Base amounts for testing (will be filtered based on balance)
BASE_TEST_AMOUNTS = [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0]

# Larry DEX ABI
LARRY_DEX_ABI = [
    {
        "inputs": [{"name": "ethAmount", "type": "uint256"}],
        "name": "getBuyLARRY",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"name": "larryAmount", "type": "uint256"}],
        "name": "LARRYtoETH",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getBacking",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "totalSupply",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

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
        "inputs": [
            {"name": "ethAmount", "type": "uint256"},
            {"name": "expectedLarryFromKyber", "type": "uint256"},
            {"name": "direction", "type": "bool"}
        ],
        "name": "simulateArbitrage",
        "outputs": [
            {"name": "wouldExecute", "type": "bool"},
            {"name": "expectedReturn", "type": "uint256"},
            {"name": "expectedProfit", "type": "uint256"}
        ],
        "stateMutability": "view",
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
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('arbitrage_bot.log')
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class TradeOpportunity:
    """Represents a profitable trade opportunity"""
    amount_eth: float
    amount_wei: int
    direction: str  # 'kyber_to_larry' or 'larry_to_kyber'
    direction_bool: bool
    larry_amount: int
    expected_output_wei: int
    expected_profit_wei: int
    profit_eth: float
    profit_percentage: float
    route_summary: dict
    timestamp: datetime

@dataclass
class BotStats:
    """Track bot performance statistics"""
    total_trades: int = 0
    successful_trades: int = 0
    failed_trades: int = 0
    total_volume_eth: float = 0
    total_profit_eth: float = 0
    gas_spent_eth: float = 0
    start_time: datetime = None
    opportunities_checked: int = 0
    profitable_opportunities: int = 0
    
    def success_rate(self) -> float:
        total = self.successful_trades + self.failed_trades
        return (self.successful_trades / total * 100) if total > 0 else 0
    
    def uptime_hours(self) -> float:
        if self.start_time:
            return (datetime.now() - self.start_time).total_seconds() / 3600
        return 0

class LarryDEXCache:
    """Cache Larry DEX state to reduce RPC calls"""
    def __init__(self, larry_contract, cache_duration=5):
        self.larry_contract = larry_contract
        self.cache_duration = cache_duration
        self.last_update = None
        self.backing = None
        self.total_supply = None
        
    async def update_if_needed(self):
        """Update cache if expired"""
        now = datetime.now()
        if not self.last_update or (now - self.last_update).seconds > self.cache_duration:
            try:
                self.backing = self.larry_contract.functions.getBacking().call()
                self.total_supply = self.larry_contract.functions.totalSupply().call()
                self.last_update = now
                logger.debug(f"Updated Larry DEX cache - Backing: {self.backing/1e18:.2f} ETH, Supply: {self.total_supply/1e18:.0f}")
            except Exception as e:
                logger.error(f"Failed to update Larry DEX cache: {e}")
    
    def estimate_larry_from_eth(self, eth_amount_wei: int) -> int:
        """Estimate LARRY output using cached values"""
        if self.backing and self.total_supply and self.backing > eth_amount_wei:
            # Bonding curve formula: (eth * totalSupply) / (backing - eth)
            return (eth_amount_wei * self.total_supply) // (self.backing - eth_amount_wei)
        return 0
    
    def estimate_eth_from_larry(self, larry_amount: int) -> int:
        """Estimate ETH output using cached values"""
        if self.backing and self.total_supply and self.total_supply > 0:
            # Inverse bonding curve: (larry * backing) / totalSupply
            return (larry_amount * self.backing) // self.total_supply
        return 0

class GasManager:
    """Manage gas prices and estimates"""
    def __init__(self, w3):
        self.w3 = w3
        self.gas_history = deque(maxlen=20)
        self.estimated_gas_used = 600000  # Conservative estimate
        
    def get_optimal_gas_price(self) -> int:
        """Get optimal gas price based on network conditions"""
        try:
            base_price = self.w3.eth.gas_price
            
            # During high opportunity periods, use higher gas
            if len(self.gas_history) > 5:
                avg_recent = statistics.mean(list(self.gas_history)[-5:])
                if avg_recent > base_price * 1.5:
                    # Network is congested, use even higher gas
                    return int(base_price * 1.3)
            
            # Normal conditions: 10% above base
            return int(base_price * 1.1)
            
        except Exception:
            return self.w3.eth.gas_price
    
    def estimate_gas_cost_eth(self) -> float:
        """Estimate transaction cost in ETH"""
        gas_price = self.get_optimal_gas_price()
        gas_cost_wei = gas_price * self.estimated_gas_used
        return gas_cost_wei / 1e18
    
    def update_gas_used(self, actual_gas: int):
        """Update gas estimate based on actual usage"""
        self.gas_history.append(actual_gas)
        if len(self.gas_history) > 3:
            # Use 95th percentile for conservative estimate
            self.estimated_gas_used = int(statistics.quantiles(
                list(self.gas_history), n=20
            )[18])

class OptimizedArbitrageBot:
    def __init__(self):
        if not PRIVATE_KEY:
            raise ValueError("PRIVATE_KEY not found in .env file")
        
        # Web3 setup
        self.w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self.account = self.w3.eth.account.from_key(PRIVATE_KEY)
        
        # Contracts
        self.contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(CONTRACT_ADDRESS),
            abi=CONTRACT_ABI
        )
        self.larry_dex = self.w3.eth.contract(
            address=Web3.to_checksum_address(LARRY_ADDRESS),
            abi=LARRY_DEX_ABI
        )
        
        # Managers
        self.dex_cache = LarryDEXCache(self.larry_dex)
        self.gas_manager = GasManager(self.w3)
        self.stats = BotStats(start_time=datetime.now())
        
        # Configuration
        self.gas_reimbursement = 0
        self.profit_recipient = ""
        self.min_profit_threshold = 0  # Can be adjusted
        self.max_retries = 3
        self.retry_delay = 2
        
        # Rate limiting for API calls
        self.kyber_api_calls = deque(maxlen=100)
        self.max_api_calls_per_minute = 50
        
        logger.info("=" * 60)
        logger.info("🚀 Optimized V3 Arbitrage Bot Starting")
        logger.info("=" * 60)
        
    async def initialize(self):
        """Initialize bot with contract data"""
        try:
            self.gas_reimbursement = self.contract.functions.gasReimbursement().call()
            self.profit_recipient = self.contract.functions.profitRecipient().call()
            
            logger.info(f"📄 Contract: {CONTRACT_ADDRESS}")
            logger.info(f"👤 Account: {self.account.address}")
            logger.info(f"⛽ Gas reimbursement: {self.gas_reimbursement/1e18:.5f} ETH")
            logger.info(f"📬 Profit recipient: {self.profit_recipient}")
            logger.info("=" * 60)
            
            # Update cache
            await self.dex_cache.update_if_needed()
            
        except Exception as e:
            logger.error(f"Failed to initialize: {e}")
            raise

    def check_rate_limit(self) -> bool:
        """Check if we're within API rate limits"""
        now = datetime.now()
        # Remove calls older than 1 minute
        while self.kyber_api_calls and (now - self.kyber_api_calls[0]).seconds > 60:
            self.kyber_api_calls.popleft()
        
        return len(self.kyber_api_calls) < self.max_api_calls_per_minute

    async def get_kyberswap_route(self, session, token_in, token_out, amount_in, retry=0):
        """Get route from KyberSwap API with retry logic"""
        if not self.check_rate_limit():
            logger.warning("Rate limit reached, waiting...")
            await asyncio.sleep(10)
        
        try:
            self.kyber_api_calls.append(datetime.now())
            
            url = "https://aggregator-api.kyberswap.com/base/api/v1/routes"
            params = {
                "tokenIn": token_in,
                "tokenOut": token_out,
                "amountIn": str(amount_in)
                # Remove gasPrice - let KyberSwap use default Base network gas pricing
            }
            
            timeout = aiohttp.ClientTimeout(total=10)
            async with session.get(url, params=params, timeout=timeout) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('data')
                elif response.status == 429:  # Rate limited
                    if retry < self.max_retries:
                        await asyncio.sleep(self.retry_delay * (retry + 1))
                        return await self.get_kyberswap_route(session, token_in, token_out, amount_in, retry + 1)
                else:
                    logger.debug(f"KyberSwap route error: {response.status}")
                    return None
                    
        except asyncio.TimeoutError:
            logger.debug("KyberSwap API timeout")
            if retry < self.max_retries:
                await asyncio.sleep(self.retry_delay)
                return await self.get_kyberswap_route(session, token_in, token_out, amount_in, retry + 1)
        except Exception as e:
            logger.debug(f"Error getting KyberSwap route: {e}")
            
        return None

    async def simulate_trade_onchain(self, eth_amount_wei: int, expected_output: int, direction: bool) -> Tuple[bool, int, int]:
        """Simulate trade on-chain to verify profitability"""
        try:
            would_execute, expected_return, expected_profit = self.contract.functions.simulateArbitrage(
                eth_amount_wei,
                expected_output,
                direction
            ).call()
            
            return would_execute, expected_return, expected_profit
            
        except Exception as e:
            logger.debug(f"Simulation failed: {e}")
            return False, 0, 0

    async def check_arbitrage_parallel(self, session, amounts: List[float]) -> List[TradeOpportunity]:
        """Check multiple amounts in parallel for efficiency"""
        self.stats.opportunities_checked += len(amounts) * 2  # Both directions
        
        tasks = []
        for amount in amounts:
            tasks.append(self.check_single_amount(session, amount))
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        opportunities = []
        for result in results:
            if isinstance(result, list):
                opportunities.extend(result)
            elif isinstance(result, Exception):
                logger.debug(f"Parallel check error: {result}")
        
        # Sort by profit
        opportunities.sort(key=lambda x: x.profit_eth, reverse=True)
        
        if opportunities:
            self.stats.profitable_opportunities += len(opportunities)
            
        return opportunities

    async def check_single_amount(self, session, amount_eth: float) -> List[TradeOpportunity]:
        """Check arbitrage opportunities for a single amount"""
        amount_wei = Web3.to_wei(amount_eth, 'ether')
        opportunities = []
        
        # Update cache
        await self.dex_cache.update_if_needed()
        
        # Check both directions concurrently
        tasks = [
            self.check_kyber_to_larry(session, amount_eth, amount_wei),
            self.check_larry_to_kyber(session, amount_eth, amount_wei)
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, TradeOpportunity):
                opportunities.append(result)
        
        return opportunities

    async def check_kyber_to_larry(self, session, amount_eth: float, amount_wei: int) -> Optional[TradeOpportunity]:
        """Check ETH -> LARRY (Kyber) -> ETH (Larry) arbitrage"""
        try:
            # Get Kyber quote
            kyber_route = await self.get_kyberswap_route(
                session, ETH_ADDRESS, LARRY_ADDRESS, amount_wei
            )
            
            if not kyber_route or not kyber_route.get('routeSummary'):
                return None
            
            larry_amount = int(kyber_route['routeSummary']['amountOut'])
            
            # Simulate on-chain
            would_execute, expected_return, expected_profit = await self.simulate_trade_onchain(
                amount_wei, larry_amount, True
            )
            
            if would_execute and expected_profit > self.min_profit_threshold:
                profit_eth = expected_profit / 1e18
                profit_pct = (expected_profit / amount_wei) * 100
                
                return TradeOpportunity(
                    amount_eth=amount_eth,
                    amount_wei=amount_wei,
                    direction='kyber_to_larry',
                    direction_bool=True,
                    larry_amount=larry_amount,
                    expected_output_wei=expected_return,
                    expected_profit_wei=expected_profit,
                    profit_eth=profit_eth,
                    profit_percentage=profit_pct,
                    route_summary=kyber_route['routeSummary'],
                    timestamp=datetime.now()
                )
                
        except Exception as e:
            logger.debug(f"Error checking Kyber->Larry: {e}")
            
        return None

    async def check_larry_to_kyber(self, session, amount_eth: float, amount_wei: int) -> Optional[TradeOpportunity]:
        """Check ETH -> LARRY (Larry) -> ETH (Kyber) arbitrage"""
        try:
            # Get LARRY amount from Larry DEX
            larry_amount = self.larry_dex.functions.getBuyLARRY(amount_wei).call()
            
            if larry_amount == 0:
                return None
            
            # Get Kyber quote for selling LARRY
            kyber_route = await self.get_kyberswap_route(
                session, LARRY_ADDRESS, ETH_ADDRESS, larry_amount
            )
            
            if not kyber_route or not kyber_route.get('routeSummary'):
                return None
            
            expected_eth = int(kyber_route['routeSummary']['amountOut'])
            
            # Simulate on-chain
            would_execute, expected_return, expected_profit = await self.simulate_trade_onchain(
                amount_wei, expected_eth, False
            )
            
            if would_execute and expected_profit > self.min_profit_threshold:
                profit_eth = expected_profit / 1e18
                profit_pct = (expected_profit / amount_wei) * 100
                
                return TradeOpportunity(
                    amount_eth=amount_eth,
                    amount_wei=amount_wei,
                    direction='larry_to_kyber',
                    direction_bool=False,
                    larry_amount=larry_amount,
                    expected_output_wei=expected_return,
                    expected_profit_wei=expected_profit,
                    profit_eth=profit_eth,
                    profit_percentage=profit_pct,
                    route_summary=kyber_route['routeSummary'],
                    timestamp=datetime.now()
                )
                
        except Exception as e:
            logger.debug(f"Error checking Larry->Kyber: {e}")
            
        return None

    async def find_optimal_amount_binary(self, session, min_amount: float, max_amount: float, direction: str) -> Optional[TradeOpportunity]:
        """Use binary search to find optimal profitable amount"""
        logger.debug(f"Binary search for {direction}: {min_amount:.4f} - {max_amount:.4f} ETH")
        
        best_opportunity = None
        iterations = 0
        max_iterations = 10
        
        while max_amount - min_amount > 0.0001 and iterations < max_iterations:
            iterations += 1
            
            # Test three points
            amounts = [
                min_amount,
                (min_amount + max_amount) / 2,
                max_amount
            ]
            
            opportunities = await self.check_arbitrage_parallel(session, amounts)
            
            # Filter for specific direction
            direction_opportunities = [
                opp for opp in opportunities 
                if opp.direction == direction
            ]
            
            if not direction_opportunities:
                break
            
            # Find the best opportunity
            best_in_batch = max(direction_opportunities, key=lambda x: x.profit_eth)
            
            if best_opportunity is None or best_in_batch.profit_eth > best_opportunity.profit_eth:
                best_opportunity = best_in_batch
            
            # Adjust search range
            profitable_amounts = [opp.amount_eth for opp in direction_opportunities]
            
            if len(profitable_amounts) == 3:
                # All amounts profitable, search higher
                min_amount = amounts[1]
            elif len(profitable_amounts) == 2:
                # Adjust based on which amounts were profitable
                if min_amount in profitable_amounts and amounts[1] in profitable_amounts:
                    max_amount = amounts[2]
                else:
                    min_amount = amounts[0]
                    max_amount = amounts[1]
            elif len(profitable_amounts) == 1:
                # Only one profitable, narrow the range
                profitable = profitable_amounts[0]
                idx = amounts.index(profitable)
                if idx == 0:
                    max_amount = amounts[1]
                elif idx == 2:
                    min_amount = amounts[1]
                else:
                    # Middle is profitable, check both sides
                    min_amount = amounts[0]
                    max_amount = amounts[2]
        
        return best_opportunity

    async def find_best_opportunity(self, session, balance_eth: float) -> Optional[TradeOpportunity]:
        """Find the best arbitrage opportunity"""
        logger.info("🔍 Searching for optimal arbitrage opportunity...")
        
        # Determine test amounts based on balance
        max_trade = min(balance_eth * 0.9, 10.0)  # Max 90% of balance or 10 ETH
        
        # Fast check with more amounts but no binary search
        test_amounts = [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0]
        test_amounts = [amt for amt in test_amounts if amt <= max_trade]
        
        # Check all amounts in parallel
        opportunities = await self.check_arbitrage_parallel(session, test_amounts)
        
        if not opportunities:
            logger.info("❌ No profitable opportunities found")
            return None
        
        # Log findings
        logger.info(f"📊 Found {len(opportunities)} opportunities")
        for opp in opportunities[:3]:  # Show top 3
            logger.info(f"  • {opp.amount_eth:.4f} ETH {opp.direction}: +{opp.profit_eth:.6f} ETH ({opp.profit_percentage:.2f}%)")
        
        # Return the best opportunity directly
        best_opportunity = opportunities[0]
        logger.info(f"🎯 Best opportunity: {best_opportunity.amount_eth:.4f} ETH {best_opportunity.direction}")
        return best_opportunity

    async def build_kyberswap_swap(self, session, route_summary) -> Optional[dict]:
        """Build swap data from KyberSwap API"""
        try:
            url = "https://aggregator-api.kyberswap.com/base/api/v1/route/build"
            deadline = int(time.time()) + 300  # 5 minutes
            
            payload = {
                "routeSummary": route_summary,
                "sender": CONTRACT_ADDRESS,
                "recipient": CONTRACT_ADDRESS,
                "slippageTolerance": 300,  # 3%
                "deadline": deadline
                # Remove enableGasEstimation - this causes the insufficient funds error
            }
            
            timeout = aiohttp.ClientTimeout(total=10)
            
            async with session.post(url, json=payload, timeout=timeout) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('data')
                else:
                    error_text = await response.text()
                    logger.error(f"KyberSwap build error {response.status}: {error_text}")
                    return None
                    
        except Exception as e:
            logger.error(f"Error building swap: {e}")
            return None

    async def execute_arbitrage(self, opportunity: TradeOpportunity) -> bool:
        """Execute the arbitrage trade"""
        try:
            self.stats.total_trades += 1
            
            logger.info("=" * 60)
            logger.info("🚀 EXECUTING ARBITRAGE TRADE")
            logger.info("=" * 60)
            logger.info(f"💰 Amount: {opportunity.amount_eth:.6f} ETH")
            logger.info(f"🔄 Direction: {opportunity.direction}")
            logger.info(f"📈 Expected profit: {opportunity.profit_eth:.6f} ETH ({opportunity.profit_percentage:.2f}%)")
            logger.info(f"⛽ Gas estimate: {self.gas_manager.estimate_gas_cost_eth():.6f} ETH")
            
            async with aiohttp.ClientSession() as session:
                # Build swap data
                swap_data_response = await self.build_kyberswap_swap(
                    session, opportunity.route_summary
                )
                
                if not swap_data_response or not swap_data_response.get('data'):
                    logger.error("Failed to build swap data")
                    self.stats.failed_trades += 1
                    return False
                
                swap_data = swap_data_response['data']
                
                # Final simulation check before execution
                would_execute, _, _ = await self.simulate_trade_onchain(
                    opportunity.amount_wei,
                    opportunity.larry_amount if opportunity.direction_bool else opportunity.expected_output_wei,
                    opportunity.direction_bool
                )
                
                if not would_execute:
                    logger.warning("Final simulation failed - market conditions changed")
                    self.stats.failed_trades += 1
                    return False
                
                # Prepare transaction
                nonce = self.w3.eth.get_transaction_count(self.account.address)
                gas_price = self.gas_manager.get_optimal_gas_price()
                
                # Build transaction
                txn = self.contract.functions.executePrincipalProtectedArbitrage(
                    bytes.fromhex(swap_data[2:] if swap_data.startswith('0x') else swap_data),
                    opportunity.direction_bool
                ).build_transaction({
                    'from': self.account.address,
                    'value': opportunity.amount_wei,
                    'gas': self.gas_manager.estimated_gas_used,
                    'gasPrice': gas_price,
                    'nonce': nonce
                })
                
                # Sign and send
                signed_txn = self.w3.eth.account.sign_transaction(txn, PRIVATE_KEY)
                tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)
                
                logger.info(f"📤 Transaction sent: {tx_hash.hex()}")
                logger.info(f"🔗 https://basescan.org/tx/{tx_hash.hex()}")
                
                # Wait for confirmation
                receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
                
                if receipt.status == 1:
                    # Update stats
                    self.stats.successful_trades += 1
                    self.stats.total_volume_eth += opportunity.amount_eth * 2
                    self.stats.total_profit_eth += opportunity.profit_eth
                    
                    gas_used = receipt.gasUsed
                    gas_cost_eth = (gas_used * gas_price) / 1e18
                    self.stats.gas_spent_eth += gas_cost_eth
                    
                    # Update gas manager
                    self.gas_manager.update_gas_used(gas_used)
                    
                    logger.info("=" * 60)
                    logger.info("✅ TRADE EXECUTED SUCCESSFULLY!")
                    logger.info(f"⛽ Gas used: {gas_used:,} ({gas_cost_eth:.6f} ETH)")
                    logger.info(f"💰 Net profit: {opportunity.profit_eth - gas_cost_eth:.6f} ETH")
                    logger.info(f"📊 Total volume: {self.stats.total_volume_eth:.2f} ETH")
                    logger.info(f"📈 Success rate: {self.stats.success_rate():.1f}%")
                    logger.info("=" * 60)
                    
                    return True
                else:
                    logger.error("❌ Transaction failed")
                    self.stats.failed_trades += 1
                    return False
                    
        except Exception as e:
            logger.error(f"Execution error: {e}")
            self.stats.failed_trades += 1
            return False

    def print_stats_summary(self):
        """Print comprehensive stats summary"""
        logger.info("\n" + "=" * 60)
        logger.info("📊 BOT PERFORMANCE SUMMARY")
        logger.info("=" * 60)
        logger.info(f"⏱️  Uptime: {self.stats.uptime_hours():.2f} hours")
        logger.info(f"🔍 Opportunities checked: {self.stats.opportunities_checked:,}")
        logger.info(f"✅ Profitable found: {self.stats.profitable_opportunities:,}")
        logger.info(f"📈 Total trades: {self.stats.total_trades}")
        logger.info(f"✅ Successful: {self.stats.successful_trades}")
        logger.info(f"❌ Failed: {self.stats.failed_trades}")
        logger.info(f"📊 Success rate: {self.stats.success_rate():.1f}%")
        logger.info(f"💰 Total volume: {self.stats.total_volume_eth:.4f} ETH")
        logger.info(f"💵 Total profit: {self.stats.total_profit_eth:.6f} ETH")
        logger.info(f"⛽ Gas spent: {self.stats.gas_spent_eth:.6f} ETH")
        logger.info(f"💸 Net profit: {self.stats.total_profit_eth - self.stats.gas_spent_eth:.6f} ETH")
        logger.info("=" * 60 + "\n")

    async def run_monitoring_loop(self):
        """Main monitoring loop"""
        logger.info("🚀 Starting monitoring loop...")
        logger.info("🔍 Will search for optimal trade amounts dynamically")
        
        consecutive_no_opportunities = 0
        check_interval = 10  # Base interval in seconds - faster for arbitrage
        
        while True:
            try:
                # Get current balance
                balance = self.w3.eth.get_balance(self.account.address)
                balance_eth = float(self.w3.from_wei(balance, 'ether'))
                
                # Skip if balance too low
                if balance_eth < 0.002:  # Minimum including gas
                    logger.warning(f"Balance too low: {balance_eth:.6f} ETH")
                    await asyncio.sleep(300)  # Wait 5 minutes
                    continue
                
                # Find best opportunity
                async with aiohttp.ClientSession() as session:
                    opportunity = await self.find_best_opportunity(session, balance_eth)
                    
                    if opportunity:
                        logger.info(f"🎯 Best opportunity: {opportunity.amount_eth:.4f} ETH {opportunity.direction}")
                        
                        # Execute trade
                        success = await self.execute_arbitrage(opportunity)
                        
                        if success:
                            consecutive_no_opportunities = 0
                            # Quick check after successful trade
                            await asyncio.sleep(5)
                            continue
                        else:
                            # Wait a bit after failed trade
                            await asyncio.sleep(30)
                    else:
                        consecutive_no_opportunities += 1
                        logger.info(f"⏳ No opportunities found ({consecutive_no_opportunities} checks)")
                
                # Dynamic interval based on market activity
                if consecutive_no_opportunities > 20:
                    interval = 60   # 1 minute for very slow market
                elif consecutive_no_opportunities > 10:
                    interval = 30   # 30 seconds for slow market
                elif consecutive_no_opportunities > 5:
                    interval = 20   # 20 seconds
                else:
                    interval = check_interval  # Normal interval (10s)
                
                # Print stats every 10 checks
                if self.stats.opportunities_checked % 50 == 0:
                    self.print_stats_summary()
                
                await asyncio.sleep(interval)
                
            except KeyboardInterrupt:
                logger.info("\n🛑 Shutdown requested...")
                self.print_stats_summary()
                break
            except Exception as e:
                logger.error(f"Loop error: {e}", exc_info=True)
                await asyncio.sleep(60)

async def main():
    """Main entry point"""
    try:
        bot = OptimizedArbitrageBot()
        await bot.initialize()
        
        # Check balance
        balance = bot.w3.eth.get_balance(bot.account.address)
        balance_eth = bot.w3.from_wei(balance, 'ether')
        
        if balance_eth < Decimal('0.002'):
            logger.error(f"Insufficient balance: {balance_eth} ETH (need at least 0.002 ETH)")
            return
        
        logger.info(f"💰 Account balance: {balance_eth:.6f} ETH")
        logger.info(f"🎯 Max trade size: {float(balance_eth) * 0.9:.6f} ETH")
        logger.info("=" * 60)
        
        await bot.run_monitoring_loop()
        
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
    finally:
        logger.info("Bot shutdown complete")

if __name__ == "__main__":
    asyncio.run(main())