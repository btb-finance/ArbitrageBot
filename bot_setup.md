# KyberSwap ↔ Larry DEX Arbitrage Bot

**Automated arbitrage trading bot that finds and executes profitable trades between KyberSwap and Larry DEX on Base network.**

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- At least 0.002 ETH in your Base wallet for trading
- Your wallet's private key

### Installation

1. **Clone/Download this repository**
```bash
git clone <repository-url>
cd arbitrage-larry
```

2. **Install Python dependencies**
```bash
pip3 install web3 aiohttp python-dotenv
```

3. **Set up your private key**
   - Open the `.env` file
   - Replace `your_private_key_here` with your actual private key:
```
PRIVATE_KEY=0xYOUR_ACTUAL_PRIVATE_KEY_HERE
BASE_RPC_URL=https://mainnet.base.org
```

4. **Fund your wallet**
   - Send at least 0.002 ETH to your wallet address on Base network
   - The bot will show your wallet address when it starts

5. **Run the bot**
```bash
python3 arbitrage_bot.py
```

## ⚙️ Configuration

Edit `arbitrage_bot.py` to customize:

```python
TRADE_AMOUNT_ETH = "0.001"        # Amount per trade
MIN_PROFIT_PERCENTAGE = 1.20     # Minimum profit % to execute (1.20% = saves gas)
```

## 📊 How It Works

1. **Monitors** KyberSwap API every 30 seconds for ETH → LARRY rates
2. **Calculates** potential profit by selling LARRY on Larry DEX
3. **Executes** trades automatically when profit > 1.20%
4. **Returns** all profits to your wallet (0% protocol fees)

## 🎯 Example Output

```
2025-05-27 11:41:16 - INFO - Bot initialized for account: 0x68f4...69a4
2025-05-27 11:41:16 - INFO - Account balance: 0.003528 ETH
2025-05-27 11:41:18 - INFO - ETH->LARRY->ETH: 0.001 ETH -> 1021.27 LARRY -> 0.001021 ETH (Profit: 2.09%)
2025-05-27 11:41:18 - INFO - 🎯 Profitable opportunity found! Profit: 2.09%
2025-05-27 11:41:20 - INFO - Transaction sent: 0xf624811c8e...
2025-05-27 11:41:24 - INFO - ✅ Arbitrage executed successfully! Gas used: 493644
```

## 🛡️ Safety Features

- **Minimum profit threshold** (1.20%) to avoid unprofitable trades
- **Gas limit protection** (800,000 gas max)
- **Real-time balance checking**
- **Comprehensive error handling**
- **Transaction confirmation waiting**

## 🔧 Technical Details

- **Contract Address**: `0xC14957db5A544167633cF8B480eB6FbB25b6da19`
- **Network**: Base Mainnet (Chain ID: 8453)
- **DEXs**: KyberSwap Aggregator + Larry DEX
- **Trade Direction**: ETH → LARRY (via KyberSwap) → ETH (via Larry DEX)

## 📝 Requirements File

Create `requirements.txt`:
```
web3>=6.0.0
aiohttp>=3.8.0
python-dotenv>=1.0.0
```

## ⚠️ Important Notes

1. **Private Key Security**: Never share your private key or commit it to version control
2. **Gas Costs**: Each trade costs ~0.001-0.002 ETH in gas fees
3. **Market Volatility**: Profit opportunities may be brief due to arbitrage competition
4. **Testing**: Start with small amounts to test the bot behavior

## 🆘 Troubleshooting

**Bot shows "Insufficient balance"**
- Send more ETH to your wallet address

**"No profitable opportunities found"**
- Market conditions may not favor arbitrage currently
- Try lowering `MIN_PROFIT_PERCENTAGE` (but watch gas costs)

**Transactions failing**
- Check your ETH balance for gas fees
- Verify Base network connectivity

**KyberSwap API errors**
- Temporary API issues, bot will retry automatically

## 💡 Tips for Success

- Run during high volatility periods for more opportunities
- Monitor gas prices (lower gas = higher profits)
- Keep adequate ETH balance for gas fees
- Watch the logs to understand market patterns

---

**Ready to start? Just follow the Quick Start guide above! 🚀**