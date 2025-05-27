// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/PriceChecker.sol";

contract CheckPricesScript is Script {
    PriceChecker public checker;
    
    function run() external {
        // Deploy price checker
        checker = new PriceChecker();
        
        console.log("=== LARRY DEX ARBITRAGE ANALYSIS ===");
        console.log("Larry DEX Address:", checker.LARRY_DEX());
        console.log("Target Profit: 0.00001 ETH");
        console.log("Test Amount: 0.005 ETH");
        console.log("");
        
        // Check specific profitability
        checkSpecificProfitability();
        
        // Check multiple amounts
        checkMultipleAmounts();
        
        // Find break-even point
        checkBreakEven();
        
        // Detailed analysis for specific amounts
        console.log("\n=== DETAILED ANALYSIS ===");
        detailedAnalysis(0.005 ether);
        detailedAnalysis(0.01 ether);
        detailedAnalysis(0.1 ether);
    }
    
    function checkMultipleAmounts() internal {
        (
            uint256[6] memory ethAmounts,
            uint256[6] memory larryAmounts, 
            uint256[6] memory ethReturns,
            int256[6] memory profits
        ) = checker.getMultipleAmountAnalysis();
        
        console.log("ETH Input | LARRY Output | ETH Return | Profit/Loss | Profit %");
        console.log("---------|-------------|-----------|------------|----------");
        
        for (uint i = 0; i < 6; i++) {
            console.log("ETH Input:", ethAmounts[i]);
            console.log("LARRY Out:", larryAmounts[i]);
            console.log("ETH Return:", ethReturns[i]);
            
            if (profits[i] >= 0) {
                console.log("Profit:", uint256(profits[i]));
                uint256 profitPercent = (uint256(profits[i]) * 10000) / ethAmounts[i]; // basis points
                console.log("Profit %:", profitPercent, "bps");
                console.log("Status: PROFITABLE");
            } else {
                console.log("Loss:", uint256(-profits[i]));
                uint256 lossPercent = (uint256(-profits[i]) * 10000) / ethAmounts[i]; // basis points
                console.log("Loss %:", lossPercent, "bps");
                console.log("Status: LOSS");
            }
            console.log("---");
        }
    }
    
    function detailedAnalysis(uint256 ethAmount) internal {
        (
            uint256 larryBuyAmount,
            uint256 ethSellAmount,
            uint256 buyPricePerToken,
            uint256 sellPricePerToken,
            int256 roundTripProfit,
            uint256 priceImpactBuy,
            uint256 priceImpactSell
        ) = checker.getDetailedAnalysis(ethAmount);
        
        console.log("Analysis for", ethAmount, "ETH:");
        console.log("  LARRY tokens received:", larryBuyAmount);
        console.log("  ETH received from selling:", ethSellAmount);
        console.log("  Buy price per LARRY:", buyPricePerToken);
        console.log("  Sell price per LARRY:", sellPricePerToken);
        console.log("  Price impact on buy:", priceImpactBuy, "bps");
        console.log("  Price impact on sell:", priceImpactSell, "bps");
        
        if (roundTripProfit >= 0) {
            console.log("  Round trip profit:", uint256(roundTripProfit), "ETH");
            console.log("  PROFITABLE ROUND TRIP");
        } else {
            console.log("  Round trip loss:", uint256(-roundTripProfit), "ETH");
            console.log("  LOSING ROUND TRIP");
        }
        console.log("");
    }
    
    function checkSpecificProfitability() internal {
        uint256 targetProfit = 0.00001 ether; // 0.00001 ETH
        uint256 testAmount = 0.005 ether;     // 0.005 ETH
        
        console.log("=== KYBERSWAP -> LARRY DEX ARBITRAGE ===");
        console.log("Strategy: Buy LARRY on KyberSwap, Sell on Larry DEX");
        console.log("Test Amount:", testAmount);
        console.log("Target Profit:", targetProfit);
        console.log("Your frontend result: 0.005044926403296908 ETH");
        console.log("");
        
        // Simulate the arbitrage: KyberSwap buy -> Larry DEX sell
        checkKyberToLarryArbitrage(testAmount, targetProfit);
        
        console.log("");
    }
    
    function checkKyberToLarryArbitrage(uint256 ethAmount, uint256 targetProfit) internal {
        console.log("=== STEP 1: SIMULATE KYBERSWAP PURCHASE ===");
        // For now, assume 1:1 ETH to LARRY on KyberSwap (we'd need real Kyber quoter)
        // But based on your frontend, you're getting more LARRY than the getBuyLARRY() shows
        
        // Your frontend shows you get 0.005044926403296908 ETH back
        // So working backwards: if selling X LARRY gives 0.005044926403296908 ETH
        uint256 frontendReturn = 5044926403296908; // 0.005044926403296908 ETH in wei
        
        // Find how much LARRY gives this return
        uint256 kyberLarryAmount = findLarryForEthReturn(frontendReturn);
        
        console.log("Assumed LARRY from KyberSwap:", kyberLarryAmount);
        console.log("(This would be from Kyber quoter in real implementation)");
        
        console.log("=== STEP 2: SELL ON LARRY DEX ===");
        uint256 ethFromLarryDex = getLarryDexSellAmount(kyberLarryAmount);
        
        console.log("ETH received from Larry DEX:", ethFromLarryDex);
        console.log("ETH received (decimal):", ethFromLarryDex / 1e15, "milliETH");
        
        console.log("=== ARBITRAGE RESULT ===");
        int256 profit = int256(ethFromLarryDex) - int256(ethAmount);
        
        if (profit > 0) {
            console.log("PROFIT:", uint256(profit), "wei");
            console.log("Profit (decimal):", uint256(profit) / 1e15, "milliETH");
            console.log("Meets target?", uint256(profit) >= targetProfit ? "YES" : "NO");
            console.log("STATUS: PROFITABLE!");
        } else {
            console.log("LOSS:", uint256(-profit), "wei");
            console.log("STATUS: NOT PROFITABLE");
        }
        
        // Also test with real getBuyLARRY for comparison
        console.log("=== COMPARISON: REAL LARRY DEX AMOUNTS ===");
        uint256 realLarryAmount = getRealLarryAmount(ethAmount);
        uint256 realEthReturn = getLarryDexSellAmount(realLarryAmount);
        
        console.log("Real Larry DEX buy:", realLarryAmount, "LARRY");
        console.log("Real Larry DEX sell return:", realEthReturn, "ETH");
        console.log("Difference in LARRY:", kyberLarryAmount > realLarryAmount ? kyberLarryAmount - realLarryAmount : 0);
    }
    
    function findLarryForEthReturn(uint256 targetEthReturn) internal view returns (uint256) {
        // Working backwards from your result: 0.005044926403296908 ETH
        // This suggests you bought more LARRY on KyberSwap than Larry DEX would give
        
        // Let's estimate: if Larry DEX gives 4.995 ETH for 4.992M LARRY
        // Then to get 5.0449 ETH, you need approximately:
        uint256 estimatedLarry = (targetEthReturn * 4992056022569853115281) / 4994999999999999;
        return estimatedLarry;
    }
    
    function getLarryDexSellAmount(uint256 larryAmount) internal view returns (uint256) {
        return checker.larryDEX().LARRYtoETH(larryAmount);
    }
    
    function getRealLarryAmount(uint256 ethAmount) internal view returns (uint256) {
        return checker.larryDEX().getBuyLARRY(ethAmount);
    }
    
    function checkBreakEven() internal {
        (uint256 breakEvenAmount, bool foundBreakEven) = checker.findBreakEvenAmount();
        
        console.log("=== BREAK-EVEN ANALYSIS ===");
        if (foundBreakEven) {
            console.log("Break-even amount found:", breakEvenAmount);
            console.log("At this amount, you won't lose money on round trips");
        } else {
            console.log("No break-even point found in tested range");
            console.log("All tested amounts result in losses");
        }
        console.log("");
    }
    
    function testAllMethods(uint256 ethAmount) internal {
        console.log("=== TESTING ALL CALCULATION METHODS ===");
        
        (
            uint256 method1_getBuyLARRY,
            uint256 method2_getBuyAmount, 
            uint256 method3_ETHtoLARRY,
            uint256 method4_ETHtoLARRYNoTrade,
            uint256 sellReturn1,
            uint256 sellReturn2,
            uint256 sellReturn3,
            uint256 sellReturn4
        ) = checker.compareAllMethods(ethAmount);
        
        console.log("Method 1 - getBuyLARRY():");
        console.log("  LARRY:", method1_getBuyLARRY);
        console.log("  ETH return:", sellReturn1);
        
        console.log("Method 2 - getBuyAmount():");
        console.log("  LARRY:", method2_getBuyAmount);
        console.log("  ETH return:", sellReturn2);
        
        console.log("Method 3 - ETHtoLARRY():");
        console.log("  LARRY:", method3_ETHtoLARRY);
        console.log("  ETH return:", sellReturn3);
        
        console.log("Method 4 - ETHtoLARRYNoTrade():");
        console.log("  LARRY:", method4_ETHtoLARRYNoTrade);
        console.log("  ETH return:", sellReturn4);
    }
}