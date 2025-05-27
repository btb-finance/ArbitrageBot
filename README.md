# KyberSwap ↔ Larry DEX Arbitrage Bot

**Automated arbitrage trading bot that finds and executes profitable trades between KyberSwap and Larry DEX on Base network.**

## 🚀 Quick Start

**Ready to earn passive income through automated arbitrage trading? Follow these simple steps:**

### 1. Prerequisites
- Python 3.8 or higher
- At least 0.002 ETH in your Base wallet for trading
- Your wallet's private key

### 2. Installation

```bash
# Clone this repository
git clone https://github.com/your-repo/arbitrage-larry.git
cd arbitrage-larry

# Install dependencies
pip3 install web3 aiohttp python-dotenv
```

### 3. Configuration

1. **Set up your private key in `.env` file:**
```env
PRIVATE_KEY=0xYOUR_ACTUAL_PRIVATE_KEY_HERE
BASE_RPC_URL=https://mainnet.base.org
```

2. **Fund your wallet with ETH on Base network** (minimum 0.002 ETH)

### 4. Run the Bot

```bash
python3 arbitrage_bot.py
```

That's it! The bot will automatically:
- ✅ Monitor for profitable arbitrage opportunities every 30 seconds
- ✅ Execute trades when profit exceeds 1.20%
- ✅ Return all profits directly to your wallet (0% fees)

## 📊 How It Works

1. **ETH → LARRY**: Uses KyberSwap to convert ETH to LARRY tokens
2. **LARRY → ETH**: Sells LARRY on Larry DEX bonding curve
3. **Profit**: Keeps the difference (typically 1-5% per successful trade)

## 🎯 Live Example

```
2025-05-27 11:41:16 - INFO - Bot initialized for account: 0x68f4...69a4
2025-05-27 11:41:16 - INFO - Account balance: 0.003528 ETH
2025-05-27 11:41:18 - INFO - ETH->LARRY->ETH: 0.001 ETH -> 1021.27 LARRY -> 0.001021 ETH (Profit: 2.09%)
2025-05-27 11:41:18 - INFO - 🎯 Profitable opportunity found! Profit: 2.09%
2025-05-27 11:41:20 - INFO - ✅ Arbitrage executed successfully!
```

## ⚙️ Configuration Options

Edit `arbitrage_bot.py` to customize:

```python
TRADE_AMOUNT_ETH = "0.001"        # Amount per trade
MIN_PROFIT_PERCENTAGE = 1.20     # Minimum profit % to execute
```

## 🛡️ Safety Features

- **Profit threshold protection** - Only trades when profitable
- **Gas limit protection** - Prevents excessive gas usage
- **Balance checking** - Ensures sufficient funds before trading
- **Error handling** - Robust error recovery and logging
- **Slippage protection** - Uses KyberSwap's built-in slippage handling

## 🔧 Technical Details

- **Smart Contract**: `0xC14957db5A544167633cF8B480eB6FbB25b6da19` (Base Mainnet)
- **Network**: Base (Chain ID: 8453)
- **DEX Integration**: KyberSwap Aggregator + Larry DEX
- **Trade Direction**: ETH → LARRY → ETH
- **Protocol Fees**: 0% (all profits go to you)

## 📈 Expected Returns

- **Typical Profit**: 1-5% per successful trade
- **Trade Frequency**: Varies with market conditions (could be multiple times per hour during volatile periods)
- **Gas Costs**: ~0.001-0.002 ETH per transaction

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Insufficient balance" | Send more ETH to your wallet |
| "No profitable opportunities" | Normal during stable markets, try lowering profit threshold |
| Transaction failures | Check ETH balance for gas fees |
| API errors | Temporary issues, bot will retry automatically |

## ⚠️ Risk Disclosure

- **Smart Contract Risk**: Interacts with audited but experimental DeFi protocols
- **Market Risk**: Arbitrage opportunities depend on market volatility
- **Gas Risk**: High network congestion can reduce profitability
- **Impermanent Loss**: None (no liquidity provision involved)

## 💡 Tips for Success

- 🕐 Run during high volatility periods for more opportunities
- ⛽ Monitor Base network gas prices
- 💰 Keep adequate ETH balance for gas fees
- 📊 Watch the logs to understand market patterns
- 🔄 Consider running multiple instances with different trade amounts

## 📁 Project Structure

```
arbitrage-larry/
├── arbitrage_bot.py          # Main bot script
├── bot_setup.md             # Detailed setup guide
├── requirements.txt         # Python dependencies
├── .env                     # Your private configuration
├── src/
│   └── ArbitrageLarryImproved.sol  # Smart contract source
└── README.md               # This file
```

## 📜 Smart Contract

The arbitrage logic is handled by our deployed smart contract at:
**`0xC14957db5A544167633cF8B480eB6FbB25b6da19`**

Contract features:
- Bidirectional arbitrage support
- MEV protection
- Gas optimization
- Emergency controls
- Zero protocol fees

## 🤝 Contributing

Found a bug or want to improve the bot? Pull requests welcome!

## 📄 License

MIT License - Feel free to fork and modify for your own use.

---

**⚡ Start earning with automated arbitrage today! ⚡**

*Disclaimer: Cryptocurrency trading involves risk. Only trade with funds you can afford to lose.*