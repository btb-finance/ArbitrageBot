// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/botv4.sol";

contract TestV4Script is Script {
    ArbitrageLarryV4 public bot;
    
    // Base chain addresses
    address constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address constant UNIVERSAL_ROUTER = 0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the bot
        bot = new ArbitrageLarryV4();
        
        console.log("=== ArbitrageLarryV4 Deployment Test ===");
        console.log("Bot deployed at:", address(bot));
        console.log("Owner:", bot.owner());
        console.log("Larry DEX:", bot.LARRY_DEX());
        console.log("Universal Router:", bot.UNIVERSAL_ROUTER());
        console.log("WETH:", bot.WETH());
        console.log("Min profit (wei):", bot.minProfitWei());
        console.log("Caller profit share:", bot.callerProfitShare(), "/ 10000");
        
        vm.stopBroadcast();
        
        // Test Larry DEX interaction
        testLarryDexInteraction();
        
        // Test profit sharing simulation
        testProfitSharingSimulation();
    }
    
    function testLarryDexInteraction() internal view {
        console.log("\n=== Larry DEX Interaction Test ===");
        
        ILarryDEX larryDex = ILarryDEX(LARRY_DEX);
        
        // Test different ETH amounts
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 0.01 ether;
        testAmounts[1] = 0.1 ether;
        testAmounts[2] = 0.5 ether;
        testAmounts[3] = 1 ether;
        testAmounts[4] = 5 ether;
        
        for (uint i = 0; i < testAmounts.length; i++) {
            uint256 ethAmount = testAmounts[i];
            console.log("ETH Amount:", ethAmount);
            
            try larryDex.getBuyLARRY(ethAmount) returns (uint256 larryAmount) {
                console.log("  Expected LARRY:", larryAmount);
                
                try larryDex.LARRYtoETH(larryAmount) returns (uint256 ethReturn) {
                    console.log("  ETH from selling LARRY:", ethReturn);
                    
                    if (ethReturn < ethAmount) {
                        uint256 slippage = ethAmount - ethReturn;
                        console.log("  Round-trip slippage:", slippage);
                        console.log("  Slippage %:", (slippage * 100) / ethAmount);
                    } else {
                        console.log("  No slippage (unexpected)");
                    }
                } catch {
                    console.log("  Error getting ETH return");
                }
            } catch {
                console.log("  Error getting LARRY amount");
            }
            console.log("  ---");
        }
    }
    
    function testProfitSharingSimulation() internal view {
        console.log("\n=== Profit Sharing Simulation ===");
        
        uint256 ethAmount = 0.1 ether;
        uint256[] memory profitScenarios = new uint256[](4);
        profitScenarios[0] = ethAmount + 0.001 ether; // 1% profit
        profitScenarios[1] = ethAmount + 0.005 ether; // 5% profit
        profitScenarios[2] = ethAmount + 0.01 ether;  // 10% profit
        profitScenarios[3] = ethAmount + 0.02 ether;  // 20% profit
        
        for (uint i = 0; i < profitScenarios.length; i++) {
            uint256 expectedReturn = profitScenarios[i];
            uint256 profit = expectedReturn - ethAmount;
            
            console.log("Scenario", i + 1, "- Profit:", profit);
            console.log("  Profit %:", (profit * 100) / ethAmount);
            
            (bool executable, uint256 callerProfit, uint256 ownerProfit) = 
                bot.isTradeExecutable(ethAmount, expectedReturn);
                
            if (executable) {
                console.log("  EXECUTABLE");
                console.log("  Caller gets:", ethAmount + callerProfit);
                console.log("  Owner gets:", ownerProfit);
                console.log("  Caller profit:", callerProfit);
                console.log("  Owner profit:", ownerProfit);
            } else {
                console.log("  NOT EXECUTABLE");
            }
            console.log("  ---");
        }
    }
}