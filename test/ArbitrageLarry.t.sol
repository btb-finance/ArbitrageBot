// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ArbitrageLarry.sol";

contract ArbitrageLarryTest is Test {
    ArbitrageLarry public arbitrage;
    
    // Fork Base mainnet to test against real contracts
    uint256 baseFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    
    address constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    
    function setUp() public {
        // Create fork of Base mainnet
        baseFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseFork);
        
        // Deploy arbitrage contract
        arbitrage = new ArbitrageLarry();
        
        // Give test contract some ETH
        vm.deal(address(this), 100 ether);
        vm.deal(address(arbitrage), 1 ether);
    }
    
    function testCheckArbitrageOpportunity() public {
        uint256 ethAmount = 0.1 ether;
        
        // Test arbitrage opportunity checking
        (
            bool profitableDirection,
            uint256 expectedProfit,
            uint256 larryPriceOnLarry,
            uint256 larryPriceOnKyber
        ) = arbitrage.checkArbitrageOpportunity(ethAmount);
        
        // Basic sanity checks
        assertTrue(larryPriceOnLarry > 0, "Larry price on Larry DEX should be > 0");
        
        // Log results for inspection
        console.log("Profitable direction (true=Larry->Kyber):", profitableDirection);
        console.log("Expected profit (wei):", expectedProfit);
        console.log("Larry price on Larry DEX:", larryPriceOnLarry);
        console.log("Larry price on Kyber:", larryPriceOnKyber);
    }
    
    function testGetLarryPriceOnLarryDex() public {
        uint256 ethAmount = 0.1 ether;
        
        uint256 larryAmount = arbitrage.getLarryPriceOnLarryDex(ethAmount);
        
        assertTrue(larryAmount > 0, "Should get some LARRY for ETH");
        console.log("LARRY amount for 0.1 ETH:", larryAmount);
        
        // Test different amounts
        uint256 larryAmount2 = arbitrage.getLarryPriceOnLarryDex(0.2 ether);
        assertTrue(larryAmount2 > larryAmount, "More ETH should get more LARRY");
    }
    
    function testGetLarrySellPriceOnLarryDex() public {
        uint256 larryAmount = 1000 * 10**18; // 1000 LARRY tokens
        
        uint256 ethAmount = arbitrage.getLarrySellPriceOnLarryDex(larryAmount);
        
        assertTrue(ethAmount > 0, "Should get some ETH for LARRY");
        console.log("ETH amount for 1000 LARRY:", ethAmount);
    }
    
    function testSetMinProfit() public {
        uint256 newMinProfit = 0.01 ether;
        
        arbitrage.setMinProfit(newMinProfit);
        
        // Check that minProfitWei was updated
        assertEq(arbitrage.minProfitWei(), newMinProfit);
    }
    
    function testSetMinProfitOnlyOwner() public {
        // Create a new address that's not the owner
        address notOwner = address(0x1234);
        
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        arbitrage.setMinProfit(0.01 ether);
    }
    
    function testEmergencyWithdraw() public {
        // Send some ETH to the contract
        vm.deal(address(arbitrage), 1 ether);
        
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 contractBalanceBefore = address(arbitrage).balance;
        
        arbitrage.emergencyWithdraw();
        
        uint256 ownerBalanceAfter = address(this).balance;
        uint256 contractBalanceAfter = address(arbitrage).balance;
        
        assertEq(contractBalanceAfter, 0, "Contract should have 0 ETH after withdrawal");
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractBalanceBefore, "Owner should receive all ETH");
    }
    
    function testEmergencyWithdrawOnlyOwner() public {
        address notOwner = address(0x1234);
        
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        arbitrage.emergencyWithdraw();
    }
    
    // Test with different ETH amounts to see price differences
    function testPriceComparison() public {
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 0.01 ether;
        testAmounts[1] = 0.1 ether;
        testAmounts[2] = 0.5 ether;
        testAmounts[3] = 1 ether;
        testAmounts[4] = 5 ether;
        
        console.log("=== Price Comparison ===");
        for (uint i = 0; i < testAmounts.length; i++) {
            (
                bool profitableDirection,
                uint256 expectedProfit,
                uint256 larryPriceOnLarry,
                uint256 larryPriceOnKyber
            ) = arbitrage.checkArbitrageOpportunity(testAmounts[i]);
            
            console.log("ETH Amount:", testAmounts[i]);
            console.log("  Larry on Larry DEX:", larryPriceOnLarry);
            console.log("  Larry on Kyber:", larryPriceOnKyber);
            console.log("  Profitable Direction:", profitableDirection ? "Larry->Kyber" : "Kyber->Larry");
            console.log("  Expected Profit:", expectedProfit);
            console.log("---");
        }
    }
    
    receive() external payable {}
}