⏺ KyberSwap Arbitrage System - Complete Integration Guide

  Overview

  This guide provides complete documentation for integrating with the KyberSwap Aggregator API to execute
  arbitrage between KyberSwap and Larry DEX on Base network.

  Contract Information

  - Contract Address: 0xC14957db5A544167633cF8B480eB6FbB25b6da19
  - Network: Base (Chain ID: 8453)
  - Larry DEX: 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888
  - KyberSwap Router: 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5

  API Endpoints

  Base URL

  https://aggregator-api.kyberswap.com/base/api/v1/

  Key Endpoints

  1. GET /routes - Get optimal swap route
  2. POST /route/build - Build executable swap data

  Token Addresses (CRITICAL)

  ✅ Correct Addresses

  const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";  // ETH (NOT WETH!)
  const LARRY_ADDRESS = "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888"; // LARRY token
  const CONTRACT_ADDRESS = "0xC14957db5A544167633cF8B480eB6FbB25b6da19"; // Our arbitrage contract

  ❌ Common Mistakes

  // DON'T USE THESE:
  const WETH_ADDRESS = "0x4200000000000000000000000000000000000006"; // This is WETH, not ETH!
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"; // Wrong for ETH

  Step-by-Step Integration

  Step 1: Get Route Information

  async function getKyberSwapRoute(tokenIn, tokenOut, amountIn) {
      const url = 'https://aggregator-api.kyberswap.com/base/api/v1/routes';

      const params = {
          tokenIn: tokenIn,           // Use exact addresses above
          tokenOut: tokenOut,         // Use exact addresses above
          amountIn: amountIn,         // Amount in wei (string)
          saveGas: '0',              // Optional: gas optimization
          gasInclude: '1',           // Include gas estimates
          clientId: 'arbitrage-bot'   // Optional: your app identifier
      };

      try {
          const response = await fetch(`${url}?${new URLSearchParams(params)}`);
          const data = await response.json();

          if (data.code === 0 && data.data && data.data.routeSummary) {
              return data.data.routeSummary;
          } else {
              throw new Error(`Route API failed: ${JSON.stringify(data)}`);
          }
      } catch (error) {
          console.error('Route API Error:', error);
          throw error;
      }
  }

  Step 2: Build Executable Swap Data

  async function buildSwapData(routeSummary, contractAddress) {
      const url = 'https://aggregator-api.kyberswap.com/base/api/v1/route/build';

      const payload = {
          routeSummary: routeSummary,        // EXACT data from Step 1
          sender: contractAddress,           // Your arbitrage contract
          recipient: contractAddress,        // Same as sender for arbitrage
          slippageTolerance: 300,           // 3% = 300 basis points
          deadline: Math.floor(Date.now() / 1000) + 1200, // 20 minutes from now
          source: 'arbitrage-bot'           // Optional: your identifier
      };

      try {
          const response = await fetch(url, {
              method: 'POST',
              headers: {
                  'Content-Type': 'application/json',
              },
              body: JSON.stringify(payload)
          });

          const data = await response.json();

          if (data.code === 0 && data.data && data.data.data) {
              return {
                  swapData: data.data.data,
                  routeSummary: routeSummary
              };
          } else {
              throw new Error(`Build API failed: ${JSON.stringify(data)}`);
          }
      } catch (error) {
          console.error('Build API Error:', error);
          throw error;
      }
  }

  Step 3: Execute Arbitrage

  // Direction 1: ETH → KyberSwap → Larry DEX
  async function executeKyberToLarryArbitrage(ethAmountWei) {
      console.log(`Executing ETH → KyberSwap → Larry arbitrage with ${ethAmountWei} wei`);

      // Step 1: Get route for ETH → LARRY
      const routeSummary = await getKyberSwapRoute(
          "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", // ETH
          "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888", // LARRY
          ethAmountWei
      );

      // Verify amounts match exactly
      if (routeSummary.amountIn !== ethAmountWei) {
          throw new Error(`Amount mismatch: expected ${ethAmountWei}, got ${routeSummary.amountIn}`);
      }

      // Step 2: Build swap data
      const { swapData } = await buildSwapData(routeSummary, CONTRACT_ADDRESS);

      // Step 3: Execute on contract
      const tx = await contract.executeArbitrageWithSwapData(
          swapData,                    // Encoded swap data
          "1",                        // Minimum return (1 wei = no minimum)
          true,                       // direction = true (Kyber → Larry)
          {
              value: ethAmountWei,    // MUST match exactly
              gasLimit: 800000        // Recommended gas limit
          }
      );

      console.log(`Transaction submitted: ${tx.hash}`);
      return tx;
  }

  // Direction 2: ETH → Larry DEX → KyberSwap  
  async function executeLarryToKyberArbitrage(ethAmountWei) {
      console.log(`Executing ETH → Larry → KyberSwap arbitrage with ${ethAmountWei} wei`);

      // First, calculate how much LARRY we'll get from Larry DEX
      const larryAmount = await larryDexContract.getBuyLARRY(ethAmountWei);

      // Get route for LARRY → ETH
      const routeSummary = await getKyberSwapRoute(
          "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888", // LARRY
          "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", // ETH
          larryAmount.toString()
      );

      // Build swap data for LARRY → ETH
      const { swapData } = await buildSwapData(routeSummary, CONTRACT_ADDRESS);

      // Execute on contract
      const tx = await contract.executeArbitrageWithSwapData(
          swapData,                    // Encoded swap data for LARRY → ETH
          "1",                        // Minimum return
          false,                      // direction = false (Larry → Kyber)
          {
              value: ethAmountWei,    // ETH to buy LARRY on Larry DEX
              gasLimit: 800000
          }
      );

      console.log(`Transaction submitted: ${tx.hash}`);
      return tx;
  }

  Complete Working Example

  const { ethers } = require('ethers');

  class KyberSwapArbitrageBot {
      constructor(provider, privateKey) {
          this.provider = provider;
          this.wallet = new ethers.Wallet(privateKey, provider);
          this.contractAddress = "0xC14957db5A544167633cF8B480eB6FbB25b6da19";

          // Contract ABI (minimal for our needs)
          this.contractABI = [
              "function executeArbitrageWithSwapData(bytes swapData, uint256 minReturnAmount, bool direction) 
  payable",
              "function checkBestArbitrageOpportunity(uint256 ethAmount) view returns (bool, bool, uint256, 
  uint256, uint256)"
          ];

          this.contract = new ethers.Contract(
              this.contractAddress,
              this.contractABI,
              this.wallet
          );
      }

      async executeArbitrage(ethAmountWei, direction) {
          try {
              console.log(`\n=== Executing Arbitrage ===`);
              console.log(`Amount: ${ethers.utils.formatEther(ethAmountWei)} ETH`);
              console.log(`Direction: ${direction ? 'Kyber → Larry' : 'Larry → Kyber'}`);

              let routeSummary, swapData;

              if (direction) {
                  // ETH → LARRY route
                  routeSummary = await this.getKyberSwapRoute(
                      "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
                      "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888",
                      ethAmountWei
                  );
              } else {
                  // Calculate LARRY amount first
                  const larryDexContract = new ethers.Contract(
                      "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888",
                      ["function getBuyLARRY(uint256) view returns (uint256)"],
                      this.provider
                  );

                  const larryAmount = await larryDexContract.getBuyLARRY(ethAmountWei);

                  // LARRY → ETH route
                  routeSummary = await this.getKyberSwapRoute(
                      "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888",
                      "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
                      larryAmount.toString()
                  );
              }

              // Build swap data
              const buildResult = await this.buildSwapData(routeSummary);
              swapData = buildResult.swapData;

              console.log(`Expected output: ${routeSummary.amountOut}`);
              console.log(`Swap data length: ${swapData.length} characters`);

              // Execute transaction
              const tx = await this.contract.executeArbitrageWithSwapData(
                  swapData,
                  "1", // Minimal return requirement
                  direction,
                  {
                      value: ethAmountWei,
                      gasLimit: 800000
                  }
              );

              console.log(`✅ Transaction submitted: ${tx.hash}`);

              // Wait for confirmation
              const receipt = await tx.wait();
              console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
              console.log(`Gas used: ${receipt.gasUsed.toString()}`);

              return receipt;

          } catch (error) {
              console.error(`❌ Arbitrage failed:`, error.message);
              throw error;
          }
      }

      async getKyberSwapRoute(tokenIn, tokenOut, amountIn) {
          const url = 'https://aggregator-api.kyberswap.com/base/api/v1/routes';
          const params = new URLSearchParams({
              tokenIn,
              tokenOut,
              amountIn,
              saveGas: '0',
              gasInclude: '1',
              clientId: 'arbitrage-bot'
          });

          const response = await fetch(`${url}?${params}`);
          const data = await response.json();

          if (data.code !== 0 || !data.data?.routeSummary) {
              throw new Error(`Route API failed: ${JSON.stringify(data)}`);
          }

          return data.data.routeSummary;
      }

      async buildSwapData(routeSummary) {
          const url = 'https://aggregator-api.kyberswap.com/base/api/v1/route/build';
          const payload = {
              routeSummary,
              sender: this.contractAddress,
              recipient: this.contractAddress,
              slippageTolerance: 300, // 3%
              deadline: Math.floor(Date.now() / 1000) + 1200, // 20 minutes
              source: 'arbitrage-bot'
          };

          const response = await fetch(url, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
          });

          const data = await response.json();

          if (data.code !== 0 || !data.data?.data) {
              throw new Error(`Build API failed: ${JSON.stringify(data)}`);
          }

          return { swapData: data.data.data, routeSummary };
      }
  }

  // Usage Example
  async function main() {
      const provider = new ethers.providers.JsonRpcProvider('https://mainnet.base.org');
      const bot = new KyberSwapArbitrageBot(provider, process.env.PRIVATE_KEY);

      const ethAmount = ethers.utils.parseEther("0.001"); // 0.001 ETH

      // Test both directions
      await bot.executeArbitrage(ethAmount, true);  // Kyber → Larry
      await bot.executeArbitrage(ethAmount, false); // Larry → Kyber
  }

  Contract Functions

  executeArbitrageWithSwapData

  function executeArbitrageWithSwapData(
      bytes calldata swapData,     // Encoded swap data from API
      uint256 minReturnAmount,     // Minimum profit (use 1 for testing)
      bool direction              // true = Kyber→Larry, false = Larry→Kyber
  ) external payable

  Parameters:

  - swapData: Hex-encoded data from KyberSwap build API
  - minReturnAmount: Minimum profit in wei (use 1 for no minimum)
  - direction:
    - true = ETH → KyberSwap → Larry DEX
    - false = ETH → Larry DEX → KyberSwap
  - msg.value: ETH amount to arbitrage (must match API amountIn exactly)

  Error Handling

  Common Errors and Solutions

  1. "Invalid msg.value"
    - Cause: ETH amount doesn't match API amountIn
    - Solution: Ensure msg.value exactly equals routeSummary.amountIn
  2. "KyberSwap trade failed"
    - Cause: Swap data expired or invalid
    - Solution: Get fresh swap data with longer deadline
  3. "Return below minimum"
    - Cause: Actual profit below minReturnAmount
    - Solution: Lower minReturnAmount or wait for better market conditions
  4. "Route not found"
    - Cause: No liquidity path available
    - Solution: Try different amount or wait for liquidity

  Best Practices

  1. Amount Validation

  // Always verify amounts match
  if (routeSummary.amountIn !== ethAmountWei.toString()) {
      throw new Error('Amount mismatch detected');
  }

  2. Fresh Data

  // Get fresh data for each transaction
  const maxAge = 60; // 1 minute
  if (Date.now() / 1000 - routeSummary.timestamp > maxAge) {
      throw new Error('Route data too old, refresh required');
  }

  3. Gas Management

  // Use appropriate gas limits
  const gasLimit = direction ? 800000 : 600000; // Kyber→Larry needs more gas

  4. Slippage Protection

  // Adjust slippage based on market conditions
  const slippage = volatileMarket ? 500 : 300; // 5% vs 3%

  5. Error Recovery

  // Retry logic for temporary failures
  for (let attempt = 1; attempt <= 3; attempt++) {
      try {
          return await executeArbitrage(amount, direction);
      } catch (error) {
          if (attempt === 3) throw error;
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
  }

  Monitoring and Analytics

  Transaction Analysis

  function analyzeTransaction(receipt) {
      const logs = receipt.logs;

      // Find arbitrage execution event
      const arbEvent = logs.find(log =>
          log.topics[0] === '0xb5b08dac11e595bf479e89de2a60157a2582562634fc72fb6e8a257e9750edf8'
      );

      if (arbEvent) {
          const decoded = ethers.utils.defaultAbiCoder.decode(
              ['bool', 'uint256', 'uint256', 'uint256', 'uint256'],
              arbEvent.data
          );

          console.log('Arbitrage Results:');
          console.log(`Direction: ${decoded[0] ? 'Kyber→Larry' : 'Larry→Kyber'}`);
          console.log(`ETH Input: ${ethers.utils.formatEther(decoded[1])} ETH`);
          console.log(`ETH Output: ${ethers.utils.formatEther(decoded[2])} ETH`);
          console.log(`Profit: ${ethers.utils.formatEther(decoded[3])} ETH`);
      }
  }

  Security Considerations

  1. Private Key Management: Never hardcode private keys
  2. Slippage Limits: Always set reasonable slippage tolerance
  3. Amount Limits: Implement maximum transaction sizes
  4. Rate Limiting: Don't spam the APIs
  5. Error Handling: Gracefully handle all failure modes

  Troubleshooting Checklist

  - Using correct token addresses (ETH vs WETH)
  - Amount matching exactly between API and transaction
  - Fresh swap data (< 5 minutes old)
  - Sufficient gas limit (800k+ recommended)
  - Proper direction parameter
  - Network connectivity to Base RPC
  - Sufficient ETH balance for transaction + gas

  This documentation provides everything needed to successfully integrate with the KyberSwap arbitrage system.
  Save this for future reference!
