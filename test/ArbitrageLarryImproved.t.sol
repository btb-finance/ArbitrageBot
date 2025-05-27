// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ArbitrageLarryImproved.sol";

contract ArbitrageLarryImprovedTest is Test {
    ArbitrageLarryImproved public arbitrage;
    
    uint256 baseFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    
    address constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    
    address user = address(0x1234);
    address owner;
    
    function setUp() public {
        // Create fork of Base mainnet
        baseFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseFork);
        
        // Deploy arbitrage contract
        arbitrage = new ArbitrageLarryImproved();
        owner = arbitrage.owner();
        
        // Give test accounts some ETH
        vm.deal(address(this), 100 ether);
        vm.deal(user, 10 ether);
        vm.deal(address(arbitrage), 1 ether);
    }
    
    function testContractDeployment() public {
        assertEq(arbitrage.owner(), address(this));
        assertEq(arbitrage.minProfitWei(), 10000000000000); // 0.00001 ETH
        assertEq(arbitrage.protocolFee(), 500); // 5%
        assertEq(arbitrage.LARRY_DEX(), LARRY_DEX);
        assertEq(arbitrage.KYBER_ROUTER(), KYBER_ROUTER);
    }
    
    function testCheckArbitrageOpportunity() public {
        uint256 ethAmount = 0.005 ether;
        
        (
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberLarryAmount,
            uint256 larryDexEthReturn
        ) = arbitrage.checkKyberToLarryArbitrage(ethAmount);
        
        console.log("Is Profitable:", isProfitable);
        console.log("Expected Profit:", expectedProfit);
        console.log("Kyber LARRY Amount:", kyberLarryAmount);
        console.log("Larry DEX ETH Return:", larryDexEthReturn);
        
        // Should be profitable based on our analysis
        assertTrue(isProfitable, "Should be profitable with current market conditions");
        assertGt(expectedProfit, 0, "Expected profit should be > 0");
        assertGe(expectedProfit, arbitrage.minProfitWei(), "Should meet minimum profit");
    }
    
    function testBatchCheckArbitrage() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.001 ether;
        amounts[1] = 0.005 ether;
        amounts[2] = 0.01 ether;
        
        (bool[] memory profitable, uint256[] memory profits) = arbitrage.batchCheckArbitrage(amounts);
        
        assertEq(profitable.length, 3, "Should return 3 results");
        assertEq(profits.length, 3, "Should return 3 profit values");
        
        // At least one should be profitable
        bool anyProfitable = false;
        for (uint i = 0; i < profitable.length; i++) {
            if (profitable[i]) {
                anyProfitable = true;
                assertGt(profits[i], 0, "Profitable trades should have profit > 0");
            }
        }
        assertTrue(anyProfitable, "At least one amount should be profitable");
    }
    
    function testGetLarryDexState() public {
        (uint256 backing, uint256 totalSupply, uint256 currentPrice) = arbitrage.getLarryDexState();
        
        assertGt(backing, 0, "Backing should be > 0");
        assertGt(totalSupply, 0, "Total supply should be > 0");
        assertGt(currentPrice, 0, "Current price should be > 0");
        
        console.log("Backing:", backing);
        console.log("Total Supply:", totalSupply);
        console.log("Current Price:", currentPrice);
    }
    
    function testSetMinProfit() public {
        uint256 newMinProfit = 0.00005 ether;
        
        arbitrage.setMinProfit(newMinProfit);
        assertEq(arbitrage.minProfitWei(), newMinProfit);
    }
    
    function testSetMinProfitOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Not owner");
        arbitrage.setMinProfit(0.00005 ether);
    }
    
    function testSetMaxSlippage() public {
        uint256 newSlippage = 500; // 5%
        
        arbitrage.setMaxSlippage(newSlippage);
        assertEq(arbitrage.maxSlippage(), newSlippage);
    }
    
    function testSetProtocolFee() public {
        uint256 newFee = 300; // 3%
        
        arbitrage.setProtocolFee(newFee);
        assertEq(arbitrage.protocolFee(), newFee);
    }
    
    function testSetProtocolFeeTooHigh() public {
        vm.expectRevert("Fee too high");
        arbitrage.setProtocolFee(1100); // 11% - too high
    }
    
    function testValidAmountModifier() public {
        // Test with 0 amount
        vm.expectRevert("Amount must be > 0");
        arbitrage.checkKyberToLarryArbitrage(0);
        
        // Test with amount too large
        vm.expectRevert("Amount too large");
        arbitrage.checkKyberToLarryArbitrage(101 ether);
    }
    
    function testBatchCheckLimitEnforcement() public {
        uint256[] memory amounts = new uint256[](11); // Too many
        for (uint i = 0; i < 11; i++) {
            amounts[i] = 0.001 ether;
        }
        
        vm.expectRevert("Too many amounts");
        arbitrage.batchCheckArbitrage(amounts);
    }
    
    function testEmergencyRecover() public {
        // Test ETH recovery
        uint256 contractBalance = address(arbitrage).balance;
        if (contractBalance > 0) {
            uint256 ownerBalanceBefore = owner.balance;
            arbitrage.emergencyRecover(address(0), contractBalance);
            assertEq(owner.balance, ownerBalanceBefore + contractBalance);
        }
    }
    
    function testEmergencyRecoverOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Not owner");
        arbitrage.emergencyRecover(address(0), 1 ether);
    }
    
    function testTransferOwnership() public {
        address newOwner = address(0x5678);
        
        arbitrage.transferOwnership(newOwner);
        assertEq(arbitrage.owner(), newOwner);
    }
    
    function testTransferOwnershipInvalidAddress() public {
        vm.expectRevert("Invalid new owner");
        arbitrage.transferOwnership(address(0));
    }
    
    function testProfitabilityWithCurrentMarketConditions() public {
        // Test with the exact amount from user's example
        uint256 testAmount = 0.005 ether;
        
        (bool isProfitable, uint256 expectedProfit,,) = arbitrage.checkKyberToLarryArbitrage(testAmount);
        
        console.log("Test Amount:", testAmount);
        console.log("Is Profitable:", isProfitable);
        console.log("Expected Profit:", expectedProfit);
        console.log("Expected Profit (milliETH):", expectedProfit / 1e15);
        console.log("Min Profit Required:", arbitrage.minProfitWei());
        
        if (isProfitable) {
            console.log("✅ PROFITABLE - Arbitrage opportunity exists!");
            assertGe(expectedProfit, arbitrage.minProfitWei(), "Profit should meet minimum");
        } else {
            console.log("❌ Not profitable at current market conditions");
        }
    }
    
    receive() external payable {}
}