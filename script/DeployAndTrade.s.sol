// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarryImproved.sol";

contract DeployAndTradeScript is Script {
    ArbitrageLarryImproved public arbitrage;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING TO BASE MAINNET ===");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the arbitrage contract
        arbitrage = new ArbitrageLarryImproved();
        
        console.log("ArbitrageLarryImproved deployed at:", address(arbitrage));
        console.log("Owner:", arbitrage.owner());
        console.log("Min Profit:", arbitrage.minProfitWei(), "wei");
        
        vm.stopBroadcast();
        
        // Check if we can trade
        checkTradeViability();
        
        // Execute the trade if profitable
        if (deployer.balance >= 0.002 ether) { // Need extra for gas
            executeTrade(deployerPrivateKey);
        } else {
            console.log("Insufficient balance for trading. Need at least 0.002 ETH");
        }
    }
    
    function checkTradeViability() internal {
        uint256 testAmount = 0.001 ether;
        
        console.log("\n=== CHECKING TRADE VIABILITY ===");
        console.log("Test amount:", testAmount, "wei (0.001 ETH)");
        
        // Check arbitrage opportunity
        (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) = arbitrage.checkBestArbitrageOpportunity(testAmount);
        
        console.log("=== ANALYSIS RESULTS ===");
        console.log("Kyber->Larry profit:", kyberToLarryProfit, "wei");
        console.log("Larry->Kyber profit:", larryToKyberProfit, "wei");
        console.log("Best direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
        console.log("Is profitable:", isProfitable);
        console.log("Expected profit:", expectedProfit, "wei");
        console.log("Min threshold:", arbitrage.minProfitWei(), "wei");
        console.log("Meets threshold:", expectedProfit >= arbitrage.minProfitWei());
        
        if (isProfitable) {
            console.log("TRADE IS PROFITABLE - Ready to execute!");
            
            // Calculate net profit after fees
            uint256 protocolFee = (expectedProfit * arbitrage.protocolFee()) / 10000;
            uint256 netProfit = expectedProfit - protocolFee;
            
            console.log("Expected gross profit:", expectedProfit, "wei");
            console.log("Protocol fee (5%):", protocolFee, "wei");
            console.log("Expected net profit:", netProfit, "wei");
            console.log("ROI:", (netProfit * 10000) / testAmount, "bps");
        } else {
            console.log("TRADE NOT PROFITABLE - Will not execute");
        }
    }
    
    function executeTrade(uint256 privateKey) internal {
        uint256 tradeAmount = 0.001 ether;
        
        console.log("\n=== EXECUTING REAL TRADE ===");
        console.log("Trade amount:", tradeAmount, "wei");
        
        // Check one more time before execution
        (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,,
        ) = arbitrage.checkBestArbitrageOpportunity(tradeAmount);
        
        if (!isProfitable) {
            console.log("Trade no longer profitable - aborting");
            return;
        }
        
        address deployer = vm.addr(privateKey);
        uint256 initialBalance = deployer.balance;
        
        console.log("Pre-trade balance:", initialBalance, "wei");
        console.log("Expected direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
        
        vm.startBroadcast(privateKey);
        
        try this.executeOptimalTrade(tradeAmount, bestDirection) {
            console.log("TRADE EXECUTED SUCCESSFULLY!");
        } catch Error(string memory reason) {
            console.log("TRADE FAILED:", reason);
        } catch {
            console.log("TRADE FAILED: Unknown error");
        }
        
        vm.stopBroadcast();
        
        // Check results
        uint256 finalBalance = deployer.balance;
        console.log("Post-trade balance:", finalBalance, "wei");
        
        if (finalBalance > initialBalance) {
            uint256 actualProfit = finalBalance - initialBalance;
            console.log("ACTUAL PROFIT:", actualProfit, "wei");
            console.log("SUCCESS: Trade was profitable!");
        } else {
            uint256 loss = initialBalance - finalBalance;
            console.log("LOSS:", loss, "wei");
            console.log("Trade resulted in loss (likely due to gas costs)");
        }
    }
    
    function executeOptimalTrade(uint256 amount, bool direction) external payable {
        if (direction) {
            // Kyber->Larry: Need to create KyberSwap parameters
            // For now, let's just test the Larry DEX directly
            console.log("Executing simplified Larry DEX trade for testing...");
            
            // Buy LARRY on Larry DEX
            ILarryDEX larryToken = arbitrage.larryToken();
            uint256 initialLarryBalance = larryToken.balanceOf(address(this));
            
            larryToken.buy{value: amount}(address(this));
            
            uint256 larryReceived = larryToken.balanceOf(address(this)) - initialLarryBalance;
            console.log("LARRY received:", larryReceived);
            
            // Sell LARRY back
            if (larryReceived > 0) {
                larryToken.sell(larryReceived);
                console.log("LARRY sold back to Larry DEX");
            }
        } else {
            console.log("Larry->Kyber direction not implemented for this test");
            revert("Direction not supported in test");
        }
    }
    
    // Fallback functions to receive ETH and LARRY
    receive() external payable {}
    fallback() external payable {}
}