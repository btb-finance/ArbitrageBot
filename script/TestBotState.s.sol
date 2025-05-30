// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/botv4.sol";

contract TestBotStateScript is Script {
    // Use the deployed bot from previous test
    ArbitrageLarryV4 constant bot = ArbitrageLarryV4(payable(0x7CB0A5Dc144833c1eB5BF1e3d7A9b850F9ebC51f));
    
    function run() external view {
        console.log("=== Testing Bot State Functions ===");
        console.log("Bot address:", address(bot));
        
        // Test getLarryDexState
        (uint256 backing, uint256 totalSupply, uint256 currentPrice) = bot.getLarryDexState();
        console.log("\nLarry DEX State:");
        console.log("  Backing:", backing);
        console.log("  Total Supply:", totalSupply);
        console.log("  Current Price:", currentPrice);
        
        // Test profit sharing
        (uint256 callerShare, uint256 ownerShare) = bot.getProfitSharing();
        console.log("\nProfit Sharing:");
        console.log("  Caller Share:", callerShare, "/ 10000");
        console.log("  Owner Share:", ownerShare, "/ 10000");
        
        // Test trade executable scenarios
        console.log("\nTrade Executable Tests:");
        uint256 testAmount = 0.1 ether;
        
        // Test different profit scenarios
        uint256[] memory testReturns = new uint256[](5);
        testReturns[0] = testAmount; // No profit
        testReturns[1] = testAmount + 0.001 ether; // 0.1% profit
        testReturns[2] = testAmount + 0.005 ether; // 0.5% profit
        testReturns[3] = testAmount + 0.01 ether; // 1% profit
        testReturns[4] = testAmount + 0.05 ether; // 5% profit
        
        for (uint i = 0; i < testReturns.length; i++) {
            (bool executable, uint256 callerProfit, uint256 ownerProfit) = 
                bot.isTradeExecutable(testAmount, testReturns[i]);
            
            uint256 totalProfit = testReturns[i] > testAmount ? testReturns[i] - testAmount : 0;
            console.log("  Scenario", i + 1, "- Total Profit:", totalProfit);
            console.log("    Executable:", executable);
            if (executable) {
                console.log("    Caller Profit:", callerProfit);
                console.log("    Owner Profit:", ownerProfit);
                console.log("    Caller Total Return:", testAmount + callerProfit);
            }
        }
        
        // Test arbitrage simulation
        console.log("\nArbitrage Simulation Tests:");
        
        // Direction 1: Uniswap -> Larry
        uint256 expectedLarry = 99814149435972356758121; // From previous test
        (bool wouldExecute1, uint256 callerReturn1, uint256 ownerReturn1) = 
            bot.simulateArbitrage(testAmount, expectedLarry, true);
        
        console.log("  Uniswap -> Larry Direction:");
        console.log("    Would Execute:", wouldExecute1);
        console.log("    Caller Return:", callerReturn1);
        console.log("    Owner Return:", ownerReturn1);
        
        // Direction 2: Larry -> Uniswap (assume better rate)
        uint256 expectedEth = testAmount + 0.002 ether;
        (bool wouldExecute2, uint256 callerReturn2, uint256 ownerReturn2) = 
            bot.simulateArbitrage(testAmount, expectedEth, false);
        
        console.log("  Larry -> Uniswap Direction:");
        console.log("    Would Execute:", wouldExecute2);
        console.log("    Caller Return:", callerReturn2);
        console.log("    Owner Return:", ownerReturn2);
    }
}