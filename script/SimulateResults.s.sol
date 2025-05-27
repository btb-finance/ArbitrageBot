// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarryImproved.sol";

contract SimulateResultsScript is Script {
    ArbitrageLarryImproved public arbitrage;
    
    function run() external {
        console.log("=== ARBITRAGE BOT EXECUTION SIMULATION ===");
        
        // Deploy the arbitrage contract
        arbitrage = new ArbitrageLarryImproved();
        
        console.log("Contract deployed at:", address(arbitrage));
        console.log("Starting simulation with 0.005 ETH...");
        console.log("");
        
        // Simulate the complete arbitrage execution
        simulateCompleteExecution();
        
        // Test multiple amounts
        simulateMultipleAmounts();
        
        // Simulate worst case scenarios
        simulateEdgeCases();
    }
    
    function simulateCompleteExecution() internal {
        uint256 inputAmount = 0.005 ether;
        
        console.log("=== STEP-BY-STEP EXECUTION SIMULATION ===");
        console.log("Input Amount:", inputAmount, "wei (0.005 ETH)");
        console.log("");
        
        // Step 1: Check both directions
        console.log("STEP 1: Analyzing both arbitrage directions...");
        (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) = arbitrage.checkBestArbitrageOpportunity(inputAmount);
        
        console.log("Direction 1 (Kyber->Larry) Profit:", kyberToLarryProfit, "wei");
        console.log("Direction 2 (Larry->Kyber) Profit:", larryToKyberProfit, "wei");
        console.log("Best Direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
        console.log("Is Profitable:", isProfitable);
        console.log("Expected Profit:", expectedProfit, "wei");
        console.log("");
        
        if (!isProfitable) {
            console.log("SIMULATION STOPPED: No profitable arbitrage found");
            return;
        }
        
        // Step 2: Simulate the winning direction
        if (bestDirection) {
            simulateKyberToLarryExecution(inputAmount);
        } else {
            simulateLarryToKyberExecution(inputAmount);
        }
        
        // Step 3: Calculate final results
        calculateFinalResults(inputAmount, expectedProfit);
    }
    
    function simulateKyberToLarryExecution(uint256 ethAmount) internal {
        console.log("STEP 2: Executing Kyber->Larry arbitrage...");
        
        // Get detailed execution data
        (
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberLarryAmount,
            uint256 larryDexEthReturn
        ) = arbitrage.checkKyberToLarryArbitrage(ethAmount);
        
        console.log("PHASE A: Buy LARRY on KyberSwap");
        console.log("  - Send", ethAmount, "wei to KyberSwap");
        console.log("  - Receive", kyberLarryAmount, "LARRY tokens");
        console.log("  - Effective rate:", (ethAmount * 1e18) / kyberLarryAmount, "wei per LARRY");
        
        console.log("PHASE B: Sell LARRY on Larry DEX");
        console.log("  - Send", kyberLarryAmount, "LARRY to Larry DEX");
        console.log("  - Receive", larryDexEthReturn, "wei ETH");
        console.log("  - Effective rate:", (larryDexEthReturn * 1e18) / kyberLarryAmount, "wei per LARRY");
        
        console.log("GROSS PROFIT:", larryDexEthReturn - ethAmount, "wei");
        console.log("");
    }
    
    function simulateLarryToKyberExecution(uint256 ethAmount) internal {
        console.log("STEP 2: Executing Larry->Kyber arbitrage...");
        
        // Get detailed execution data
        (
            bool isProfitable,
            uint256 expectedProfit,
            uint256 larryDexLarryAmount,
            uint256 kyberEthReturn
        ) = arbitrage.checkLarryToKyberArbitrage(ethAmount);
        
        console.log("PHASE A: Buy LARRY on Larry DEX");
        console.log("  - Send", ethAmount, "wei to Larry DEX");
        console.log("  - Receive", larryDexLarryAmount, "LARRY tokens");
        console.log("  - Effective rate:", (ethAmount * 1e18) / larryDexLarryAmount, "wei per LARRY");
        
        console.log("PHASE B: Sell LARRY on KyberSwap");
        console.log("  - Send", larryDexLarryAmount, "LARRY to KyberSwap");
        console.log("  - Receive", kyberEthReturn, "wei ETH");
        console.log("  - Effective rate:", (kyberEthReturn * 1e18) / larryDexLarryAmount, "wei per LARRY");
        
        console.log("GROSS PROFIT:", kyberEthReturn - ethAmount, "wei");
        console.log("");
    }
    
    function calculateFinalResults(uint256 inputAmount, uint256 grossProfit) internal {
        console.log("STEP 3: Final profit calculation...");
        
        uint256 protocolFee = arbitrage.protocolFee();
        uint256 protocolFeeAmount = (grossProfit * protocolFee) / 10000;
        uint256 netProfit = grossProfit - protocolFeeAmount;
        
        console.log("FINANCIAL BREAKDOWN:");
        console.log("  Input Amount:", inputAmount, "wei");
        console.log("  Gross Profit:", grossProfit, "wei");
        console.log("  Protocol Fee (5%):", protocolFeeAmount, "wei");
        console.log("  Net Profit to User:", netProfit, "wei");
        console.log("  ROI:", (netProfit * 10000) / inputAmount, "bps");
        console.log("  ROI Percentage:", (netProfit * 100) / inputAmount / 100, "%");
        
        // Convert to more readable units
        console.log("");
        console.log("PROFIT IN DIFFERENT UNITS:");
        console.log("  Net Profit:", netProfit / 1e15, "milliETH");
        console.log("  Net Profit:", netProfit / 1e9, "gwei");
        console.log("  Target was:", arbitrage.minProfitWei(), "wei");
        console.log("  Achievement:", (netProfit * 100) / arbitrage.minProfitWei(), "% of target");
        
        if (netProfit >= arbitrage.minProfitWei()) {
            console.log("  STATUS: SUCCESS - Target achieved!");
        } else {
            console.log("  STATUS: FAILED - Below minimum threshold");
        }
        console.log("");
    }
    
    function simulateMultipleAmounts() internal {
        console.log("=== SIMULATION: MULTIPLE AMOUNTS ===");
        
        uint256[] memory testAmounts = new uint256[](6);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.005 ether;
        testAmounts[2] = 0.01 ether;
        testAmounts[3] = 0.05 ether;
        testAmounts[4] = 0.1 ether;
        testAmounts[5] = 1 ether;
        
        console.log("Amount (ETH) | Profitable | Direction | Gross Profit | Net Profit | ROI %");
        console.log("-------------|------------|-----------|--------------|------------|------");
        
        for (uint i = 0; i < testAmounts.length; i++) {
            (
                bool bestDirection,
                bool isProfitable,
                uint256 expectedProfit,
                uint256 kyberToLarryProfit,
                uint256 larryToKyberProfit
            ) = arbitrage.checkBestArbitrageOpportunity(testAmounts[i]);
            
            uint256 netProfit = 0;
            uint256 roi = 0;
            
            if (isProfitable) {
                uint256 protocolFeeAmount = (expectedProfit * arbitrage.protocolFee()) / 10000;
                netProfit = expectedProfit - protocolFeeAmount;
                roi = (netProfit * 10000) / testAmounts[i]; // basis points
            }
            
            console.log("ETH:", testAmounts[i] / 1e18);
            console.log("  Profitable:", isProfitable);
            console.log("  Direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
            console.log("  Gross Profit:", expectedProfit, "wei");
            console.log("  Net Profit:", netProfit, "wei");
            console.log("  ROI:", roi, "bps");
            
            if (isProfitable) {
                console.log("  POTENTIAL EARNINGS: $", calculateUSDValue(netProfit), "(at $3000/ETH)");
            }
            console.log("  ---");
        }
    }
    
    function simulateEdgeCases() internal {
        console.log("=== EDGE CASE SIMULATIONS ===");
        
        // Test minimum amount
        console.log("TEST 1: Minimum profitable amount");
        uint256 minAmount = findMinimumProfitableAmount();
        console.log("Minimum profitable amount found:", minAmount, "wei");
        console.log("Minimum profitable amount:", minAmount / 1e15, "milliETH");
        
        // Test very large amount
        console.log("\nTEST 2: Large amount test (10 ETH)");
        uint256 largeAmount = 10 ether;
        (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) = arbitrage.checkBestArbitrageOpportunity(largeAmount);
        
        if (isProfitable) {
            uint256 netProfit = expectedProfit - ((expectedProfit * arbitrage.protocolFee()) / 10000);
            console.log("Large amount profitable:", isProfitable);
            console.log("Expected net profit:", netProfit, "wei");
            console.log("Expected net profit:", netProfit / 1e18, "ETH");
            console.log("Potential USD value:", calculateUSDValue(netProfit), "(at $3000/ETH)");
        } else {
            console.log("Large amount not profitable - may hit slippage limits");
        }
        
        // Test boundary conditions
        console.log("\nTEST 3: Boundary conditions");
        testBoundaryConditions();
    }
    
    function findMinimumProfitableAmount() internal returns (uint256) {
        uint256 minThreshold = arbitrage.minProfitWei();
        
        // Binary search for minimum profitable amount
        uint256 low = 0.0001 ether;
        uint256 high = 0.01 ether;
        
        for (uint256 i = 0; i < 20; i++) {
            uint256 mid = (low + high) / 2;
            (,bool isProfitable, uint256 profit,,) = arbitrage.checkBestArbitrageOpportunity(mid);
            
            if (isProfitable && profit >= minThreshold) {
                high = mid;
            } else {
                low = mid;
            }
        }
        
        return high;
    }
    
    function testBoundaryConditions() internal {
        console.log("Testing amounts near profitability threshold...");
        
        uint256[] memory borderAmounts = new uint256[](5);
        borderAmounts[0] = 0.0045 ether;
        borderAmounts[1] = 0.0048 ether;
        borderAmounts[2] = 0.005 ether;
        borderAmounts[3] = 0.0052 ether;
        borderAmounts[4] = 0.0055 ether;
        
        for (uint i = 0; i < borderAmounts.length; i++) {
            (,bool isProfitable, uint256 profit,,) = arbitrage.checkBestArbitrageOpportunity(borderAmounts[i]);
            console.log("Amount:", borderAmounts[i] / 1e15, "milliETH");
            console.log("  Profitable:", isProfitable);
            console.log("  Profit:", profit, "wei");
            console.log("  Meets threshold:", profit >= arbitrage.minProfitWei());
        }
    }
    
    function calculateUSDValue(uint256 weiAmount) internal pure returns (uint256) {
        // Assume 1 ETH = $3000
        return (weiAmount * 3000) / 1e18;
    }
}