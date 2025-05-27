# Arbitrage Bot Setup Instructions

## Prerequisites
- Python 3.8+
- At least 0.002 ETH in your wallet for trading
- Private key for your wallet

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure the bot:
Edit `arbitrage_bot.py` and replace `YOUR_PRIVATE_KEY_HERE` with your actual private key.

## Running the Bot

```bash
python arbitrage_bot.py
```

## Configuration Options

In `arbitrage_bot.py`, you can modify:
- `TRADE_AMOUNT_ETH`: Amount to trade (default: 0.002 ETH)
- `MIN_PROFIT_PERCENTAGE`: Minimum profit % to execute trade (default: 1%)

## Bot Features

- ✅ Monitors KyberSwap ↔ Larry DEX arbitrage opportunities every 30 seconds
- ✅ Uses 0.002 ETH per trade as requested
- ✅ Automatic profit calculation and execution
- ✅ Real-time logging of opportunities and trades
- ✅ Error handling and retry logic
- ✅ Works with deployed contract at 0xC14957db5A544167633cF8B480eB6FbB25b6da19

## Safety Notes

- Bot only trades when profit exceeds minimum threshold
- Uses slippage protection on all trades
- Includes gas limit protection
- Logs all activity for monitoring