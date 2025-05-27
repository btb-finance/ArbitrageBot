// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarryImproved.sol";

contract ExecuteTradeScript is Script {
    // Use deployed contract address
    ArbitrageLarryImproved public arbitrage = ArbitrageLarryImproved(payable(0xD812B8aC539928c3a17adaA8574622431C815841));
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== EXECUTING ARBITRAGE TRADE ===");
        console.log("Contract:", address(arbitrage));
        console.log("Trader:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        
        // Test different amounts to find profitable one
        findProfitableAmount();
        
        // Execute trade if funded
        if (deployer.balance >= 0.002 ether) {
            executeRealTrade(deployerPrivateKey);
        } else {
            console.log("\nNEED FUNDING:");
            console.log("Send ETH to:", deployer);
            console.log("Minimum needed: 0.002 ETH (for trade + gas)");
            console.log("Recommended: 0.005+ ETH");
        }
    }
    
    function findProfitableAmount() internal {
        console.log("\n=== FINDING PROFITABLE AMOUNT ===");
        
        uint256[] memory testAmounts = new uint256[](8);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.0011 ether;
        testAmounts[2] = 0.0012 ether;
        testAmounts[3] = 0.0015 ether;
        testAmounts[4] = 0.002 ether;
        testAmounts[5] = 0.005 ether;
        testAmounts[6] = 0.01 ether;
        testAmounts[7] = 0.02 ether;
        
        uint256 minThreshold = arbitrage.minProfitWei();
        console.log("Min profit threshold:", minThreshold, "wei");
        console.log("");
        
        for (uint i = 0; i < testAmounts.length; i++) {
            (
                bool bestDirection,
                bool isProfitable,
                uint256 expectedProfit,
                uint256 kyberToLarryProfit,
                uint256 larryToKyberProfit
            ) = arbitrage.checkBestArbitrageOpportunity(testAmounts[i]);
            
            console.log("Amount:", testAmounts[i] / 1e15, "milliETH");
            console.log("  Kyber->Larry:", kyberToLarryProfit, "wei");
            console.log("  Larry->Kyber:", larryToKyberProfit, "wei");
            console.log("  Best direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
            console.log("  Expected profit:", expectedProfit, "wei");
            console.log("  Profitable:", isProfitable);
            
            if (isProfitable) {
                uint256 netProfit = expectedProfit - ((expectedProfit * arbitrage.protocolFee()) / 10000);
                console.log("  Net profit after fees:", netProfit, "wei");
                console.log("  ROI:", (netProfit * 10000) / testAmounts[i], "bps");
                console.log("  STATUS: PROFITABLE!");
            } else {
                console.log("  STATUS: Not profitable");
            }
            console.log("  ---");
        }
    }
    
    function executeRealTrade(uint256 privateKey) internal {
        console.log("\n=== EXECUTING REAL ARBITRAGE TRADE ===");
        
        // Use amount that we know is profitable (from our analysis)
        uint256 tradeAmount = 0.0012 ether; // Slightly above minimum
        
        address deployer = vm.addr(privateKey);
        
        if (deployer.balance < tradeAmount + 0.001 ether) {
            console.log("Insufficient balance for trade + gas");
            return;
        }
        
        console.log("Trade amount:", tradeAmount);
        console.log("Pre-trade balance:", deployer.balance);
        
        // Final profitability check
        (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,,
        ) = arbitrage.checkBestArbitrageOpportunity(tradeAmount);
        
        if (!isProfitable) {
            console.log("Trade no longer profitable - market may have changed");
            return;
        }
        
        console.log("Expected profit:", expectedProfit, "wei");
        console.log("Direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
        
        vm.startBroadcast(privateKey);
        
        try this.executeSimpleTrade{value: tradeAmount}() {
            console.log("TRADE EXECUTED SUCCESSFULLY!");
        } catch Error(string memory reason) {
            console.log("TRADE FAILED:", reason);
        } catch {
            console.log("TRADE FAILED: Unknown error");
        }
        
        vm.stopBroadcast();
        
        // Check final results
        uint256 finalBalance = deployer.balance;
        console.log("Post-trade balance:", finalBalance);
        
        // Calculate actual profit/loss (accounting for gas costs)
        console.log("\n=== TRADE RESULTS ===");
        console.log("Note: Results include gas costs");
    }
    
    function executeSimpleTrade() external payable {
        require(msg.value > 0, "Must send ETH");
        
        console.log("Executing simplified round-trip trade on Larry DEX...");
        console.log("Amount sent:", msg.value);
        
        // Get Larry DEX interface
        ILarryDEX larryDEX = arbitrage.larryToken();
        
        // Record initial state
        uint256 initialETH = address(this).balance - msg.value;
        uint256 initialLARRY = larryDEX.balanceOf(address(this));
        
        console.log("Initial ETH:", initialETH);
        console.log("Initial LARRY:", initialLARRY);
        
        // Step 1: Buy LARRY
        larryDEX.buy{value: msg.value}(address(this));
        uint256 larryReceived = larryDEX.balanceOf(address(this)) - initialLARRY;
        console.log("LARRY received:", larryReceived);
        
        if (larryReceived == 0) {
            revert("No LARRY received from purchase");
        }
        
        // Step 2: Sell LARRY back
        larryDEX.sell(larryReceived);
        
        uint256 finalETH = address(this).balance;
        uint256 finalLARRY = larryDEX.balanceOf(address(this));
        
        console.log("Final ETH:", finalETH);
        console.log("Final LARRY:", finalLARRY);
        
        // Calculate round-trip result
        if (finalETH > initialETH) {
            uint256 profit = finalETH - initialETH;
            console.log("Round-trip profit:", profit, "wei");
        } else {
            uint256 loss = initialETH - finalETH;
            console.log("Round-trip loss:", loss, "wei");
        }
        
        // Send back any ETH to trader
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }
    
    receive() external payable {}
}