// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface ILarryDEX {
    function buy(address receiver) external payable;
    function sell(uint256 larry) external;
    function getBuyLARRY(uint256 amount) external view returns (uint256);
    function LARRYtoETH(uint256 value) external view returns (uint256);
    function getBacking() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract TestLarryDexScript is Script {
    address constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Larry DEX Buy/Sell Test ===");
        console.log("Deployer address:", deployer);
        console.log("Initial balance:", deployer.balance);
        
        ILarryDEX larryDex = ILarryDEX(LARRY_DEX);
        
        // Check Larry DEX state
        uint256 backing = larryDex.getBacking();
        uint256 totalSupply = larryDex.totalSupply();
        console.log("Larry DEX backing:", backing);
        console.log("Larry DEX total supply:", totalSupply);
        
        uint256 testAmount = 0.001 ether; // Small amount for testing
        
        // Check how much LARRY we would get
        uint256 expectedLarry = larryDex.getBuyLARRY(testAmount);
        console.log("Expected LARRY for", testAmount, "ETH:", expectedLarry);
        
        // Check how much ETH we would get back
        uint256 expectedEthReturn = larryDex.LARRYtoETH(expectedLarry);
        console.log("Expected ETH return for", expectedLarry, "LARRY:", expectedEthReturn);
        
        // Calculate slippage
        if (expectedEthReturn < testAmount) {
            uint256 slippage = testAmount - expectedEthReturn;
            console.log("Round-trip slippage:", slippage);
            console.log("Slippage percentage:", (slippage * 100) / testAmount, "%");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Actual buy test
        console.log("\n=== Executing Buy Test ===");
        uint256 balanceBefore = deployer.balance;
        uint256 larryBalanceBefore = larryDex.balanceOf(deployer);
        
        larryDex.buy{value: testAmount}(deployer);
        
        uint256 balanceAfter = deployer.balance;
        uint256 larryBalanceAfter = larryDex.balanceOf(deployer);
        
        console.log("ETH spent:", balanceBefore - balanceAfter);
        console.log("LARRY received:", larryBalanceAfter - larryBalanceBefore);
        
        // Actual sell test
        console.log("\n=== Executing Sell Test ===");
        uint256 larryToSell = larryBalanceAfter - larryBalanceBefore;
        
        if (larryToSell > 0) {
            uint256 ethBalanceBefore = deployer.balance;
            larryDex.sell(larryToSell);
            uint256 ethBalanceAfter = deployer.balance;
            
            console.log("LARRY sold:", larryToSell);
            console.log("ETH received:", ethBalanceAfter - ethBalanceBefore);
            
            // Final slippage calculation
            uint256 totalEthSpent = balanceBefore - ethBalanceAfter;
            console.log("Total ETH lost in round-trip:", totalEthSpent);
            console.log("Final slippage percentage:", (totalEthSpent * 100) / testAmount, "%");
        } else {
            console.log("No LARRY received to sell");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== Test Complete ===");
        console.log("Final balance:", deployer.balance);
        console.log("Final LARRY balance:", larryDex.balanceOf(deployer));
    }
}