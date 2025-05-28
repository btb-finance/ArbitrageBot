# V3 Arbitrage Bot Successfully Deployed! 🎉

## Contract Information

- **V3 Contract Address**: `0x7Bee2beF4adC5504CD747106924304d26CcFBd94`
- **Network**: Base Mainnet
- **Deployment Transaction**: [0x60e1a05c2b9f6cef5841c3ae5e79e324d39db2a46dc87bf11e4ec63810d9cc99](https://basescan.org/tx/0x60e1a05c2b9f6cef5841c3ae5e79e324d39db2a46dc87bf11e4ec63810d9cc99)

## Configuration

- **Owner**: `0x68f4322ce72E3DE5B4DbC33976Ba4c7E65e969a4` (you)
- **Profit Recipient**: `0xfed2Ff614E0289D41937139730B49Ee158D02299` ✅
- **Gas Reimbursement**: 0.00005 ETH per trade
- **Min Profit**: 0 (volume generation mode)
- **Protocol Fee**: 5%

## How It Works

1. **Principal Protection**: You always get your 0.002 ETH back
2. **Gas Reimbursement**: Additional 0.00005 ETH per trade
3. **Profit Distribution**: Any profits go to `0xfed2Ff614E0289D41937139730B49Ee158D02299`
4. **Volume Generation**: Helps LPs earn fees from trading volume

## Run The Bot

Update the CONTRACT_ADDRESS in your bot file to:
```python
CONTRACT_ADDRESS = "0x7Bee2beF4adC5504CD747106924304d26CcFBd94"
```

Then run:
```bash
python3 arbitrage_bot_v3.py
```

## Verify on BaseScan

View your deployed contract:
https://basescan.org/address/0x7Bee2beF4adC5504CD747106924304d26CcFBd94