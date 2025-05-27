// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILarryDEX {
    function getBuyLARRY(uint256 amount) external view returns (uint256);
    function getBuyAmount(uint256 amount) external view returns (uint256);
    function LARRYtoETH(uint256 value) external view returns (uint256);
    function getBacking() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    
    // Additional functions that might be used by frontend
    function ETHtoLARRY(uint256 value) external view returns (uint256);
    function ETHtoLARRYNoTrade(uint256 value) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PriceChecker {
    address public constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    
    ILarryDEX public immutable larryDEX;
    
    constructor() {
        larryDEX = ILarryDEX(LARRY_DEX);
    }
    
    function checkPricesAndProfit(uint256 ethAmount) external view returns (
        uint256 larryFromLarryDEX,
        uint256 ethFromSellingLarry,
        int256 profitLoss,
        uint256 currentPrice,
        uint256 backing,
        uint256 totalSupply
    ) {
        // Get how much LARRY we can buy with ETH on Larry DEX
        larryFromLarryDEX = larryDEX.getBuyLARRY(ethAmount);
        
        // Get how much ETH we'd get back selling that LARRY
        ethFromSellingLarry = larryDEX.LARRYtoETH(larryFromLarryDEX);
        
        // Calculate profit/loss
        profitLoss = int256(ethFromSellingLarry) - int256(ethAmount);
        
        // Get current backing and supply for price calculation
        backing = larryDEX.getBacking();
        totalSupply = larryDEX.totalSupply();
        
        // Current LARRY price in ETH (backing per token)
        currentPrice = (backing * 1 ether) / totalSupply;
    }
    
    function getDetailedAnalysis(uint256 ethAmount) external view returns (
        uint256 larryBuyAmount,
        uint256 ethSellAmount, 
        uint256 buyPricePerToken,
        uint256 sellPricePerToken,
        int256 roundTripProfit,
        uint256 priceImpactBuy,
        uint256 priceImpactSell
    ) {
        // Get LARRY amount for buying
        larryBuyAmount = larryDEX.getBuyLARRY(ethAmount);
        
        // Get ETH amount for selling that LARRY
        ethSellAmount = larryDEX.LARRYtoETH(larryBuyAmount);
        
        // Calculate effective prices
        if (larryBuyAmount > 0) {
            buyPricePerToken = (ethAmount * 1 ether) / larryBuyAmount;
        }
        
        if (ethSellAmount > 0 && larryBuyAmount > 0) {
            sellPricePerToken = (ethSellAmount * 1 ether) / larryBuyAmount;
        }
        
        // Round trip profit/loss
        roundTripProfit = int256(ethSellAmount) - int256(ethAmount);
        
        // Price impact calculations
        uint256 currentPrice = (larryDEX.getBacking() * 1 ether) / larryDEX.totalSupply();
        
        if (currentPrice > 0) {
            if (buyPricePerToken > currentPrice) {
                priceImpactBuy = ((buyPricePerToken - currentPrice) * 10000) / currentPrice; // in basis points
            }
            
            if (sellPricePerToken < currentPrice) {
                priceImpactSell = ((currentPrice - sellPricePerToken) * 10000) / currentPrice; // in basis points
            }
        }
    }
    
    function getMultipleAmountAnalysis() external view returns (
        uint256[6] memory ethAmounts,
        uint256[6] memory larryAmounts,
        uint256[6] memory ethReturns,
        int256[6] memory profits
    ) {
        ethAmounts[0] = 0.005 ether;
        ethAmounts[1] = 0.01 ether;
        ethAmounts[2] = 0.05 ether;
        ethAmounts[3] = 0.1 ether;
        ethAmounts[4] = 0.5 ether;
        ethAmounts[5] = 1 ether;
        
        for (uint i = 0; i < 6; i++) {
            larryAmounts[i] = larryDEX.getBuyLARRY(ethAmounts[i]);
            ethReturns[i] = larryDEX.LARRYtoETH(larryAmounts[i]);
            profits[i] = int256(ethReturns[i]) - int256(ethAmounts[i]);
        }
    }
    
    function checkProfitability(uint256 ethAmount, uint256 minProfitWei) external view returns (
        bool isProfitable,
        uint256 larryAmount,
        uint256 ethReturn,
        int256 actualProfit,
        uint256 profitInWei
    ) {
        larryAmount = larryDEX.getBuyLARRY(ethAmount);
        ethReturn = larryDEX.LARRYtoETH(larryAmount);
        actualProfit = int256(ethReturn) - int256(ethAmount);
        
        if (actualProfit > 0) {
            profitInWei = uint256(actualProfit);
            isProfitable = profitInWei >= minProfitWei;
        } else {
            isProfitable = false;
            profitInWei = 0;
        }
    }
    
    function findBreakEvenAmount() external view returns (
        uint256 breakEvenAmount,
        bool foundBreakEven
    ) {
        // Test different amounts to find break-even point
        uint256[] memory testAmounts = new uint256[](20);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.002 ether;
        testAmounts[2] = 0.003 ether;
        testAmounts[3] = 0.004 ether;
        testAmounts[4] = 0.005 ether;
        testAmounts[5] = 0.006 ether;
        testAmounts[6] = 0.007 ether;
        testAmounts[7] = 0.008 ether;
        testAmounts[8] = 0.009 ether;
        testAmounts[9] = 0.01 ether;
        testAmounts[10] = 0.02 ether;
        testAmounts[11] = 0.03 ether;
        testAmounts[12] = 0.04 ether;
        testAmounts[13] = 0.05 ether;
        testAmounts[14] = 0.1 ether;
        testAmounts[15] = 0.2 ether;
        testAmounts[16] = 0.5 ether;
        testAmounts[17] = 1 ether;
        testAmounts[18] = 2 ether;
        testAmounts[19] = 5 ether;
        
        for (uint i = 0; i < testAmounts.length; i++) {
            uint256 larryAmount = larryDEX.getBuyLARRY(testAmounts[i]);
            uint256 ethReturn = larryDEX.LARRYtoETH(larryAmount);
            
            if (ethReturn >= testAmounts[i]) {
                breakEvenAmount = testAmounts[i];
                foundBreakEven = true;
                return (breakEvenAmount, foundBreakEven);
            }
        }
        
        foundBreakEven = false;
    }
    
    function compareAllMethods(uint256 ethAmount) external view returns (
        uint256 method1_getBuyLARRY,
        uint256 method2_getBuyAmount, 
        uint256 method3_ETHtoLARRY,
        uint256 method4_ETHtoLARRYNoTrade,
        uint256 sellReturn1,
        uint256 sellReturn2,
        uint256 sellReturn3,
        uint256 sellReturn4
    ) {
        // Try different buy methods
        try larryDEX.getBuyLARRY(ethAmount) returns (uint256 result) {
            method1_getBuyLARRY = result;
            sellReturn1 = larryDEX.LARRYtoETH(result);
        } catch {}
        
        try larryDEX.getBuyAmount(ethAmount) returns (uint256 result) {
            method2_getBuyAmount = result;
            sellReturn2 = larryDEX.LARRYtoETH(result);
        } catch {}
        
        try larryDEX.ETHtoLARRY(ethAmount) returns (uint256 result) {
            method3_ETHtoLARRY = result;
            sellReturn3 = larryDEX.LARRYtoETH(result);
        } catch {}
        
        try larryDEX.ETHtoLARRYNoTrade(ethAmount) returns (uint256 result) {
            method4_ETHtoLARRYNoTrade = result;
            sellReturn4 = larryDEX.LARRYtoETH(result);
        } catch {}
    }
    
    function debugCalculation(uint256 ethAmount) external view returns (
        uint256 backing,
        uint256 totalSupply,
        uint256 currentPrice,
        uint256 larryFromBuy,
        uint256 ethFromSell,
        int256 netResult
    ) {
        backing = larryDEX.getBacking();
        totalSupply = larryDEX.totalSupply();
        currentPrice = (backing * 1 ether) / totalSupply;
        
        larryFromBuy = larryDEX.getBuyLARRY(ethAmount);
        ethFromSell = larryDEX.LARRYtoETH(larryFromBuy);
        netResult = int256(ethFromSell) - int256(ethAmount);
    }
}