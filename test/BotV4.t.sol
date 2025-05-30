// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/botv4.sol";

contract BotV4Test is Test {
    ArbitrageLarryV4 public bot;
    
    // Fork Base mainnet for testing
    uint256 baseFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    
    // Base chain addresses
    address constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address constant UNIVERSAL_ROUTER = 0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    function setUp() public {
        // Create fork of Base mainnet
        baseFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseFork);
        
        // Deploy bot contract
        bot = new ArbitrageLarryV4();
        
        // Fund test accounts
        vm.deal(address(this), 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(address(bot), 1 ether);
        
        console.log("Bot deployed at:", address(bot));
        console.log("Owner:", bot.owner());
        console.log("Initial profit share (caller):", bot.callerProfitShare());
    }
    
    function testBotDeployment() public {
        // Verify deployment
        assertEq(bot.LARRY_DEX(), LARRY_DEX);
        assertEq(bot.UNIVERSAL_ROUTER(), UNIVERSAL_ROUTER);
        assertEq(bot.WETH(), WETH);
        assertEq(bot.owner(), address(this));
        assertEq(bot.callerProfitShare(), 5000); // 50%
        assertEq(bot.minProfitWei(), 0);
    }
    
    function testLarryDexBuySell() public {
        console.log("=== Testing Larry DEX Buy/Sell ===");
        
        ILarryDEX larryDex = ILarryDEX(LARRY_DEX);
        uint256 ethAmount = 0.1 ether;
        
        // Check initial state
        uint256 initialBacking = larryDex.getBacking();
        uint256 initialSupply = larryDex.totalSupply();
        console.log("Initial backing:", initialBacking);
        console.log("Initial supply:", initialSupply);
        
        // Test buy prediction
        uint256 expectedLarry = larryDex.getBuyLARRY(ethAmount);
        console.log("Expected LARRY for", ethAmount, "ETH:", expectedLarry);
        assertTrue(expectedLarry > 0, "Should get some LARRY");
        
        // Actually buy LARRY
        uint256 balanceBefore = address(this).balance;
        larryDex.buy{value: ethAmount}(address(this));
        uint256 balanceAfter = address(this).balance;
        uint256 larryBalance = larryDex.balanceOf(address(this));
        
        console.log("ETH spent:", balanceBefore - balanceAfter);
        console.log("LARRY received:", larryBalance);
        assertGt(larryBalance, 0, "Should receive LARRY tokens");
        
        // Test sell prediction
        uint256 expectedEth = larryDex.LARRYtoETH(larryBalance);
        console.log("Expected ETH for", larryBalance, "LARRY:", expectedEth);
        
        // Actually sell LARRY
        uint256 ethBalanceBefore = address(this).balance;
        larryDex.sell(larryBalance);
        uint256 ethBalanceAfter = address(this).balance;
        uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;
        
        console.log("ETH received from sell:", ethReceived);
        assertGt(ethReceived, 0, "Should receive ETH from sell");
        
        // Check if there's slippage
        uint256 slippage = ethAmount > ethReceived ? ethAmount - ethReceived : 0;
        console.log("Round-trip slippage:", slippage);
        console.log("Slippage percentage:", slippage * 100 / ethAmount, "%");
    }
    
    function testGetLarryDexState() public {
        console.log("=== Testing Larry DEX State Functions ===");
        
        (uint256 backing, uint256 totalSupply, uint256 currentPrice) = bot.getLarryDexState();
        
        console.log("Backing:", backing);
        console.log("Total Supply:", totalSupply);
        console.log("Current Price:", currentPrice);
        
        assertTrue(backing > 0, "Backing should be > 0");
        assertTrue(totalSupply > 0, "Total supply should be > 0");
        assertTrue(currentPrice > 0, "Current price should be > 0");
    }
    
    function testSimulateArbitrage() public {
        console.log("=== Testing Arbitrage Simulation ===");
        
        uint256 ethAmount = 0.1 ether;
        
        // Test both directions
        console.log("Testing Uniswap -> Larry direction:");
        uint256 expectedLarry = ILarryDEX(LARRY_DEX).getBuyLARRY(ethAmount);
        (bool wouldExecute1, uint256 callerReturn1, uint256 ownerReturn1) = 
            bot.simulateArbitrage(ethAmount, expectedLarry, true);
        
        console.log("Would execute:", wouldExecute1);
        console.log("Caller return:", callerReturn1);
        console.log("Owner return:", ownerReturn1);
        
        console.log("Testing Larry -> Uniswap direction:");
        (bool wouldExecute2, uint256 callerReturn2, uint256 ownerReturn2) = 
            bot.simulateArbitrage(ethAmount, ethAmount + 0.01 ether, false);
        
        console.log("Would execute:", wouldExecute2);
        console.log("Caller return:", callerReturn2);
        console.log("Owner return:", ownerReturn2);
    }
    
    function testIsTradeExecutable() public {
        console.log("=== Testing Trade Executable Check ===");
        
        uint256 ethAmount = 0.1 ether;
        uint256 expectedReturn = ethAmount + 0.01 ether; // 1% profit
        
        (bool executable, uint256 callerProfit, uint256 ownerProfit) = 
            bot.isTradeExecutable(ethAmount, expectedReturn);
        
        console.log("Trade executable:", executable);
        console.log("Caller profit:", callerProfit);
        console.log("Owner profit:", ownerProfit);
        
        assertTrue(executable, "Trade should be executable with profit");
        assertEq(callerProfit + ownerProfit, 0.01 ether, "Profits should sum to total profit");
        
        // Test with 50/50 split
        assertEq(callerProfit, ownerProfit, "Should be equal with 50/50 split");
    }
    
    function testProfitSharingConfiguration() public {
        console.log("=== Testing Profit Sharing Configuration ===");
        
        // Test setting different profit shares
        bot.setProfitSharing(7000); // 70% to caller
        assertEq(bot.callerProfitShare(), 7000);
        
        (uint256 callerShare, uint256 ownerShare) = bot.getProfitSharing();
        assertEq(callerShare, 7000);
        assertEq(ownerShare, 3000);
        assertEq(callerShare + ownerShare, 10000);
        
        // Test with 0% to caller (100% to owner)
        bot.setProfitSharing(0);
        assertEq(bot.callerProfitShare(), 0);
        
        // Test with 100% to caller (0% to owner)
        bot.setProfitSharing(10000);
        assertEq(bot.callerProfitShare(), 10000);
        
        // Test invalid share (should revert)
        vm.expectRevert("Share exceeds 100%");
        bot.setProfitSharing(10001);
    }
    
    function testMinProfitSetting() public {
        console.log("=== Testing Min Profit Setting ===");
        
        // Initially 0
        assertEq(bot.minProfitWei(), 0);
        
        // Set minimum profit
        uint256 newMinProfit = 0.001 ether;
        bot.setMinProfit(newMinProfit);
        assertEq(bot.minProfitWei(), newMinProfit);
        
        // Test trade executable with min profit
        uint256 ethAmount = 0.1 ether;
        uint256 smallProfit = ethAmount + 0.0005 ether; // Less than min
        uint256 goodProfit = ethAmount + 0.002 ether; // More than min
        
        (bool executable1,,) = bot.isTradeExecutable(ethAmount, smallProfit);
        assertFalse(executable1, "Should not be executable below min profit");
        
        (bool executable2,,) = bot.isTradeExecutable(ethAmount, goodProfit);
        assertTrue(executable2, "Should be executable above min profit");
    }
    
    function testOwnerOnlyFunctions() public {
        console.log("=== Testing Owner-Only Functions ===");
        
        // Test as non-owner
        vm.prank(user1);
        vm.expectRevert("Not owner");
        bot.setProfitSharing(6000);
        
        vm.prank(user1);
        vm.expectRevert("Not owner");
        bot.setMinProfit(0.01 ether);
        
        vm.prank(user1);
        vm.expectRevert("Not owner");
        bot.transferOwnership(user2);
        
        // Test ownership transfer
        bot.transferOwnership(user1);
        assertEq(bot.owner(), user1);
        
        // Test new owner can call functions
        vm.prank(user1);
        bot.setProfitSharing(6000);
        assertEq(bot.callerProfitShare(), 6000);
    }
    
    function testEmergencyRecover() public {
        console.log("=== Testing Emergency Recovery ===");
        
        // Send some ETH to contract
        vm.deal(address(bot), 2 ether);
        uint256 contractBalance = address(bot).balance;
        uint256 ownerBalanceBefore = address(this).balance;
        
        // Recover ETH
        bot.emergencyRecover(address(0), 1 ether);
        
        assertEq(address(bot).balance, contractBalance - 1 ether);
        assertEq(address(this).balance, ownerBalanceBefore + 1 ether);
        
        // Test non-owner cannot recover
        vm.prank(user1);
        vm.expectRevert("Not owner");
        bot.emergencyRecover(address(0), 1 ether);
    }
    
    function testFailExecuteArbitrageWithoutETH() public {
        // Should fail with no ETH
        bytes memory emptyData = "";
        bot.executeArbitrage(true, emptyData, block.timestamp + 1);
    }
    
    function testFailExecuteArbitrageWithoutSwapData() public {
        // Should fail with empty swap data
        bytes memory emptyData = "";
        bot.executeArbitrage{value: 0.1 ether}(true, emptyData, block.timestamp + 1);
    }
    
    receive() external payable {}
}