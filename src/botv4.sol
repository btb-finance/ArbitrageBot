// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function allowance(address owner, address spender) external view returns (uint256);
}

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
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniversalRouter {
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;
    
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external payable;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address guy, uint256 wad) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/**
 * @title ArbitrageLarryV4 - Volume Generation with Profit Splitting
 * @notice Arbitrage between Uniswap (V2/V3/V4) and Larry DEX with profit sharing
 * @dev Uses Universal Router for all Uniswap interactions
 * 
 * Key Features:
 * - Uses Uniswap Universal Router for V2/V3/V4 swaps
 * - Admin-controlled profit splitting between caller and owner
 * - Principal Protection: Callers always get their ETH back or tx reverts
 * - Volume Focused: Generates trading volume for LP fees
 * - Risk-Free Operation: Market makers can run without capital risk
 * 
 * Profit Distribution:
 * - Caller gets: Principal + (Profit * callerProfitShare / 10000)
 * - Owner gets: Profit * (10000 - callerProfitShare) / 10000
 * 
 * Universal Router Commands:
 * - 0x00: V3_SWAP_EXACT_IN
 * - 0x08: V2_SWAP_EXACT_IN  
 * - 0x10: V4_SWAP
 * - 0x0c: UNWRAP_WETH
 */
contract ArbitrageLarryV4 {
    // Base chain addresses
    address public constant UNIVERSAL_ROUTER = 0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC;
    address public constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address public constant WETH = 0x4200000000000000000000000000000000000006; // Base WETH
    
    // Universal Router command bytes
    bytes1 public constant V2_SWAP_EXACT_IN = 0x08;
    bytes1 public constant V3_SWAP_EXACT_IN = 0x00;
    bytes1 public constant V4_SWAP = 0x10;
    bytes1 public constant UNWRAP_WETH = 0x0c;
    bytes1 public constant SWEEP = 0x04;
    
    ILarryDEX public immutable larryToken;
    IUniversalRouter public immutable universalRouter;
    IWETH public immutable weth;
    
    address public owner;
    uint256 public minProfitWei = 0; // No minimum - volume is the goal
    
    // Profit sharing configuration
    uint256 public callerProfitShare = 5000; // 50% to caller (in basis points)
    uint256 public constant MAX_PROFIT_SHARE = 10000; // 100% in basis points
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        larryToken = ILarryDEX(LARRY_DEX);
        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER);
        weth = IWETH(WETH);
        owner = msg.sender;
        
        // Pre-approve tokens for Universal Router
        larryToken.approve(UNIVERSAL_ROUTER, type(uint256).max);
        weth.approve(UNIVERSAL_ROUTER, type(uint256).max);
    }
    
    /**
     * @notice Set profit sharing configuration
     * @param _callerProfitShare Share of profit for caller in basis points (0-10000)
     * @dev Owner gets the remaining share automatically
     */
    function setProfitSharing(uint256 _callerProfitShare) external onlyOwner {
        require(_callerProfitShare <= MAX_PROFIT_SHARE, "Share exceeds 100%");
        callerProfitShare = _callerProfitShare;
    }
    
    /**
     * @notice Set minimum profit threshold (can be 0 for volume generation)
     * @param _minProfitWei New minimum profit in wei (0 = volume mode)
     */
    function setMinProfit(uint256 _minProfitWei) external onlyOwner {
        minProfitWei = _minProfitWei;
    }
    
    /**
     * @notice Execute principal-protected arbitrage with profit splitting
     * @param direction True = Uniswap->Larry, False = Larry->Uniswap
     * @param swapData Encoded swap data for Universal Router
     * @param deadline Deadline for the swap
     * @dev Distributes profits according to callerProfitShare
     */
    function executeArbitrage(
        bool direction,
        bytes calldata swapData,
        uint256 deadline
    ) external payable {
        require(msg.value > 0, "Must send ETH");
        require(swapData.length > 0, "Invalid swap data");
        
        uint256 principalAmount = msg.value;
        uint256 initialContractBalance = address(this).balance - principalAmount;
        
        if (direction) {
            // Direction 1: ETH -> LARRY (via Uniswap) -> ETH (via Larry DEX)
            _executeUniswapToLarry(principalAmount, swapData, deadline);
        } else {
            // Direction 2: ETH -> LARRY (via Larry DEX) -> ETH (via Uniswap)
            _executeLarryToUniswap(principalAmount, swapData, deadline);
        }
        
        uint256 finalContractBalance = address(this).balance;
        uint256 totalReturn = finalContractBalance - initialContractBalance;
        
        // Ensure we have at least the principal back
        require(totalReturn >= principalAmount, "Insufficient return to cover principal");
        
        // Calculate total profit
        uint256 totalProfit = totalReturn - principalAmount;
        
        // Check minimum profit requirement
        require(totalProfit >= minProfitWei, "Profit below minimum threshold");
        
        // Split profit between caller and owner
        uint256 callerProfit = 0;
        uint256 ownerProfit = 0;
        
        if (totalProfit > 0) {
            callerProfit = (totalProfit * callerProfitShare) / MAX_PROFIT_SHARE;
            ownerProfit = totalProfit - callerProfit;
            
            // Transfer owner's profit share
            if (ownerProfit > 0) {
                payable(owner).transfer(ownerProfit);
            }
        }
        
        // Return principal + caller's profit share to caller
        uint256 callerReturn = principalAmount + callerProfit;
        payable(msg.sender).transfer(callerReturn);
    }
    
    /**
     * @notice Internal: Execute Uniswap -> Larry arbitrage
     */
    function _executeUniswapToLarry(
        uint256 ethAmount,
        bytes calldata swapData,
        uint256 deadline
    ) internal {
        // Execute swap on Universal Router
        bytes memory commands = abi.encodePacked(swapData[0]); // First byte is the command
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = swapData[1:]; // Rest is the input data
        
        // Execute the swap
        universalRouter.execute{value: ethAmount}(commands, inputs, deadline);
        
        // Get LARRY balance after Uniswap swap
        uint256 larryBalance = larryToken.balanceOf(address(this));
        require(larryBalance > 0, "No LARRY received from Uniswap");
        
        // Sell LARRY back to ETH on Larry DEX
        larryToken.sell(larryBalance);
    }
    
    /**
     * @notice Internal: Execute Larry -> Uniswap arbitrage
     */
    function _executeLarryToUniswap(
        uint256 ethAmount,
        bytes calldata swapData,
        uint256 deadline
    ) internal {
        // Buy LARRY on Larry DEX with ETH
        larryToken.buy{value: ethAmount}(address(this));
        uint256 larryBalance = larryToken.balanceOf(address(this));
        require(larryBalance > 0, "No LARRY received from Larry DEX");
        
        // Ensure LARRY is approved for Universal Router (reapprove if needed)
        if (larryToken.allowance(address(this), UNIVERSAL_ROUTER) < larryBalance) {
            larryToken.approve(UNIVERSAL_ROUTER, type(uint256).max);
        }
        
        // Execute swap on Universal Router (LARRY -> ETH)
        bytes memory commands = abi.encodePacked(swapData[0]); // First byte is the command
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = swapData[1:]; // Rest is the input data
        
        // Execute the swap (no ETH value for token->ETH swaps)
        universalRouter.execute(commands, inputs, deadline);
        
        // If we received WETH, unwrap it
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) {
            weth.withdraw(wethBalance);
        }
    }
    
    /**
     * @notice Check if a trade would be executable and profitable
     * @param ethAmount Amount of ETH to trade
     * @param expectedReturn Expected ETH return from arbitrage
     * @return executable Whether the trade would execute successfully
     * @return netProfitForCaller Net profit the caller would receive
     * @return netProfitForOwner Net profit the owner would receive
     */
    function isTradeExecutable(uint256 ethAmount, uint256 expectedReturn) 
        external 
        view 
        returns (
            bool executable, 
            uint256 netProfitForCaller,
            uint256 netProfitForOwner
        ) 
    {
        if (expectedReturn <= ethAmount) {
            return (false, 0, 0);
        }
        
        uint256 totalProfit = expectedReturn - ethAmount;
        
        if (totalProfit < minProfitWei) {
            return (false, 0, 0);
        }
        
        netProfitForCaller = (totalProfit * callerProfitShare) / MAX_PROFIT_SHARE;
        netProfitForOwner = totalProfit - netProfitForCaller;
        
        return (true, netProfitForCaller, netProfitForOwner);
    }
    
    /**
     * @notice Simulate arbitrage with profit distribution
     * @param ethAmount Amount of ETH to use
     * @param expectedOutput Expected output from the arbitrage
     * @param direction True = Uniswap->Larry, False = Larry->Uniswap
     * @return wouldExecute Whether the trade would execute successfully
     * @return callerReturn Total return for the caller (principal + profit share)
     * @return ownerReturn Total return for the owner (profit share only)
     */
    function simulateArbitrage(
        uint256 ethAmount,
        uint256 expectedOutput,
        bool direction
    ) external view returns (
        bool wouldExecute,
        uint256 callerReturn,
        uint256 ownerReturn
    ) {
        uint256 expectedReturn;
        
        if (direction) {
            // Uniswap -> Larry: expectedOutput is LARRY amount
            expectedReturn = larryToken.LARRYtoETH(expectedOutput);
        } else {
            // Larry -> Uniswap: expectedOutput is ETH amount
            expectedReturn = expectedOutput;
        }
        
        if (expectedReturn <= ethAmount) {
            return (false, 0, 0);
        }
        
        uint256 totalProfit = expectedReturn - ethAmount;
        
        if (totalProfit < minProfitWei) {
            return (false, 0, 0);
        }
        
        uint256 callerProfit = (totalProfit * callerProfitShare) / MAX_PROFIT_SHARE;
        uint256 ownerProfit = totalProfit - callerProfit;
        
        callerReturn = ethAmount + callerProfit;
        ownerReturn = ownerProfit;
        wouldExecute = true;
    }
    
    /**
     * @notice Get current Larry DEX state
     * @return backing Current backing in ETH
     * @return totalSupply Total LARRY supply
     * @return currentPrice Current LARRY price in ETH (per token)
     */
    function getLarryDexState() 
        external 
        view 
        returns (uint256 backing, uint256 totalSupply, uint256 currentPrice) 
    {
        backing = larryToken.getBacking();
        totalSupply = larryToken.totalSupply();
        if (totalSupply > 0) {
            currentPrice = (backing * 1 ether) / totalSupply;
        }
    }
    
    /**
     * @notice Get current profit sharing configuration
     * @return callerShare Caller's profit share in basis points
     * @return ownerShare Owner's profit share in basis points
     */
    function getProfitSharing() 
        external 
        view 
        returns (uint256 callerShare, uint256 ownerShare) 
    {
        callerShare = callerProfitShare;
        ownerShare = MAX_PROFIT_SHARE - callerProfitShare;
    }
    
    /**
     * @notice Emergency function to recover stuck tokens
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to recover
     */
    function emergencyRecover(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            require(amount <= address(this).balance, "Insufficient ETH balance");
            payable(owner).transfer(amount);
        } else {
            IERC20(token).transfer(owner, amount);
        }
    }
    
    /**
     * @notice Update token approvals if needed
     */
    function updateApprovals() external onlyOwner {
        larryToken.approve(UNIVERSAL_ROUTER, type(uint256).max);
        weth.approve(UNIVERSAL_ROUTER, type(uint256).max);
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
    
    receive() external payable {}
}