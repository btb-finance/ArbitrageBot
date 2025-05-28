// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
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

interface IKyberSwapRouter {
    struct SwapDescriptionV2 {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address[] feeReceivers;
        uint256[] feeAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct SwapExecutionParams {
        address callTarget;
        address approveTarget;
        bytes targetData;
        SwapDescriptionV2 desc;
        bytes clientData;
    }

    function swapGeneric(SwapExecutionParams calldata execution)
        external
        payable
        returns (uint256 returnAmount, uint256 gasUsed);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address guy, uint256 wad) external returns (bool);
}

// Interface for KyberSwap quoter to get real prices
interface IKyberQuoter {
    function getAmountsOut(uint256 amountIn, address[] calldata path) 
        external view returns (uint256[] memory amounts);
}

contract ArbitrageLarryImprovedV2 {
    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant LARRY_DEX = 0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888;
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0x4200000000000000000000000000000000000006; // Base WETH
    
    ILarryDEX public immutable larryToken;
    IKyberSwapRouter public immutable kyberRouter;
    IWETH public immutable weth;
    
    address public owner;
    uint256 public minProfitWei = 5000000000000; // 0.000005 ETH (to support 0.5% profit margins)
    uint256 public maxSlippage = 300; // 3% in basis points
    uint256 public protocolFee = 500; // 5% protocol fee in basis points
    
    // Events
    event ArbitrageExecuted(
        address indexed trader,
        uint256 ethInput,
        uint256 larryAmount,
        uint256 profit,
        uint256 timestamp
    );
    
    event ArbitrageDirectionExecuted(
        address indexed trader,
        bool direction, // true = Kyber->Larry, false = Larry->Kyber
        uint256 ethInput,
        uint256 ethOutput,
        uint256 profit,
        uint256 timestamp
    );
    
    event ProfitabilityCheck(
        uint256 ethAmount,
        uint256 kyberLarryAmount,
        uint256 larryDexEthReturn,
        uint256 expectedProfit,
        bool isProfitable
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be > 0");
        require(amount <= 100 ether, "Amount too large");
        _;
    }
    
    constructor() {
        larryToken = ILarryDEX(LARRY_DEX);
        kyberRouter = IKyberSwapRouter(KYBER_ROUTER);
        weth = IWETH(WETH);
        owner = msg.sender;
        
        // Pre-approve LARRY token for KyberSwap router
        larryToken.approve(KYBER_ROUTER, type(uint256).max);
        // Pre-approve WETH for KyberSwap router
        weth.approve(KYBER_ROUTER, type(uint256).max);
    }
    
    /**
     * @notice Set minimum profit threshold
     * @param _minProfitWei New minimum profit in wei
     */
    function setMinProfit(uint256 _minProfitWei) external onlyOwner {
        require(_minProfitWei <= 0.01 ether, "Min profit too high");
        minProfitWei = _minProfitWei;
    }
    
    /**
     * @notice Set maximum slippage tolerance
     * @param _maxSlippage New max slippage in basis points (e.g., 300 = 3%)
     */
    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        require(_maxSlippage <= 1000, "Slippage too high"); // Max 10%
        maxSlippage = _maxSlippage;
    }
    
    /**
     * @notice Set protocol fee
     * @param _protocolFee New protocol fee in basis points
     */
    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        require(_protocolFee <= 1000, "Fee too high"); // Max 10%
        protocolFee = _protocolFee;
    }
    
    /**
     * @notice Execute arbitrage with pre-built swap data from KyberSwap API
     * @param swapData Encoded swap data from KyberSwap Aggregator API
     * @param minReturnAmount Minimum amount to receive from arbitrage
     * @param direction True = ETH-to-LARRY(Kyber)-to-ETH(Larry), False = ETH-to-LARRY(Larry)-to-ETH(Kyber)
     */
    function executeArbitrageWithSwapData(
        bytes calldata swapData,
        uint256 minReturnAmount,
        bool direction
    ) external payable {
        require(msg.value > 0, "Must send ETH");
        require(swapData.length > 0, "Invalid swap data");
        
        uint256 initialBalance = address(this).balance - msg.value;
        
        if (direction) {
            // Direction 1: ETH to LARRY (via KyberSwap) to ETH (via Larry DEX)
            _executeKyberToLarryWithData(msg.value, swapData);
        } else {
            // Direction 2: ETH to LARRY (via Larry DEX) to ETH (via KyberSwap)
            _executeLarryToKyberWithData(msg.value, swapData);
        }
        
        uint256 finalBalance = address(this).balance;
        require(finalBalance > initialBalance, "Trade resulted in loss");
        
        uint256 grossProfit = finalBalance - initialBalance;
        require(grossProfit >= minProfitWei, "Profit below minimum threshold");
        require(grossProfit >= minReturnAmount, "Return below minimum");
        
        // Take protocol fee
        uint256 fee = (grossProfit * protocolFee) / 10000;
        uint256 netProfit = grossProfit - fee;
        
        // Send fee to owner
        if (fee > 0) {
            payable(owner).transfer(fee);
        }
        
        // Send net profit and initial ETH back to trader
        uint256 totalReturn = initialBalance + netProfit;
        if (totalReturn > 0) {
            payable(msg.sender).transfer(totalReturn);
        }
        
        emit ArbitrageDirectionExecuted(
            msg.sender,
            direction,
            msg.value,
            totalReturn,
            netProfit,
            block.timestamp
        );
    }
    
    /**
     * @notice Internal: Execute Kyber -> Larry arbitrage with swap data
     */
    function _executeKyberToLarryWithData(uint256 ethAmount, bytes calldata swapData) internal {
        // Execute KyberSwap trade: ETH to LARRY
        (bool success, bytes memory returnData) = KYBER_ROUTER.call{value: ethAmount}(swapData);
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert("KyberSwap ETH->LARRY trade failed");
            }
        }
        
        // Get LARRY balance after KyberSwap
        uint256 larryBalance = larryToken.balanceOf(address(this));
        require(larryBalance > 0, "No LARRY received from KyberSwap");
        
        // Sell LARRY back to ETH on Larry DEX
        larryToken.sell(larryBalance);
    }
    
    /**
     * @notice Internal: Execute Larry -> Kyber arbitrage with swap data
     */
    function _executeLarryToKyberWithData(uint256 ethAmount, bytes calldata swapData) internal {
        // Buy LARRY on Larry DEX with ETH
        larryToken.buy{value: ethAmount}(address(this));
        uint256 larryBalance = larryToken.balanceOf(address(this));
        require(larryBalance > 0, "No LARRY received from Larry DEX");
        
        // Ensure LARRY is approved for KyberSwap (reapprove if needed)
        if (larryToken.allowance(address(this), KYBER_ROUTER) < larryBalance) {
            larryToken.approve(KYBER_ROUTER, type(uint256).max);
        }
        
        // Execute KyberSwap trade: LARRY to ETH
        // Note: For token->ETH swaps, KyberSwap doesn't need ETH value
        (bool success, bytes memory returnData) = KYBER_ROUTER.call(swapData);
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert("KyberSwap LARRY->ETH trade failed");
            }
        }
    }
    
    /**
     * @notice Execute arbitrage using KyberSwap router params (no pre-built data)
     * @param ethAmount Amount of ETH to arbitrage
     * @param kyberParams KyberSwap execution parameters
     * @param direction True = Kyber->Larry, False = Larry->Kyber
     */
    function executeArbitrageWithParams(
        uint256 ethAmount,
        IKyberSwapRouter.SwapExecutionParams calldata kyberParams,
        bool direction
    ) external payable validAmount(ethAmount) {
        require(msg.value >= ethAmount, "Insufficient ETH sent");
        
        uint256 initialBalance = address(this).balance - msg.value;
        uint256 ethUsed;
        uint256 profit;
        
        if (direction) {
            // Kyber -> Larry
            ethUsed = ethAmount;
            
            // Buy LARRY on KyberSwap
            (uint256 larryReceived,) = kyberRouter.swapGeneric{value: ethUsed}(kyberParams);
            require(larryReceived > 0, "No LARRY received from KyberSwap");
            
            // Sell LARRY on Larry DEX
            larryToken.sell(larryReceived);
            
        } else {
            // Larry -> Kyber
            ethUsed = ethAmount;
            
            // Buy LARRY on Larry DEX
            larryToken.buy{value: ethUsed}(address(this));
            uint256 larryBalance = larryToken.balanceOf(address(this));
            require(larryBalance > 0, "No LARRY received from Larry DEX");
            
            // Ensure approval
            if (larryToken.allowance(address(this), KYBER_ROUTER) < larryBalance) {
                larryToken.approve(KYBER_ROUTER, type(uint256).max);
            }
            
            // Sell LARRY on KyberSwap
            (uint256 ethReceived,) = kyberRouter.swapGeneric(kyberParams);
            require(ethReceived > 0, "No ETH received from KyberSwap");
        }
        
        uint256 finalBalance = address(this).balance;
        require(finalBalance > initialBalance, "Trade resulted in loss");
        
        profit = finalBalance - initialBalance;
        require(profit >= minProfitWei, "Profit below minimum");
        
        // Calculate and distribute profits
        uint256 fee = (profit * protocolFee) / 10000;
        uint256 netProfit = profit - fee;
        
        if (fee > 0) {
            payable(owner).transfer(fee);
        }
        
        uint256 totalReturn = initialBalance + netProfit;
        if (totalReturn > 0) {
            payable(msg.sender).transfer(totalReturn);
        }
        
        emit ArbitrageDirectionExecuted(
            msg.sender,
            direction,
            ethUsed,
            totalReturn,
            netProfit,
            block.timestamp
        );
    }
    
    /**
     * @notice Check arbitrage opportunities in BOTH directions
     * @param ethAmount Amount of ETH to use for arbitrage
     * @return bestDirection True = Kyber->Larry, False = Larry->Kyber
     * @return isProfitable Whether any arbitrage is profitable
     * @return expectedProfit Expected profit in wei
     * @return kyberToLarryProfit Profit from Kyber->Larry direction
     * @return larryToKyberProfit Profit from Larry->Kyber direction
     */
    function checkBestArbitrageOpportunity(uint256 ethAmount) 
        external 
        view 
        validAmount(ethAmount)
        returns (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) 
    {
        // Check Direction 1: KyberSwap -> Larry DEX
        uint256 kyberLarryAmount = _estimateKyberLarryAmount(ethAmount);
        uint256 larryDexEthReturn = larryToken.LARRYtoETH(kyberLarryAmount);
        
        if (larryDexEthReturn > ethAmount) {
            kyberToLarryProfit = larryDexEthReturn - ethAmount;
        }
        
        // Check Direction 2: Larry DEX -> KyberSwap
        uint256 larryDexLarryAmount = larryToken.getBuyLARRY(ethAmount);
        uint256 kyberEthReturn = _estimateKyberEthReturn(larryDexLarryAmount);
        
        if (kyberEthReturn > ethAmount) {
            larryToKyberProfit = kyberEthReturn - ethAmount;
        }
        
        // Determine best direction
        if (kyberToLarryProfit > larryToKyberProfit) {
            bestDirection = true; // Kyber -> Larry
            expectedProfit = kyberToLarryProfit;
        } else {
            bestDirection = false; // Larry -> Kyber
            expectedProfit = larryToKyberProfit;
        }
        
        isProfitable = expectedProfit >= minProfitWei;
    }
    
    /**
     * @notice Get current Larry DEX state for analysis
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
     * @notice Estimate LARRY amount from KyberSwap
     * @dev This is a simplified estimation. In production, use real KyberSwap quoter
     * @param ethAmount ETH amount to swap
     * @return Estimated LARRY amount
     */
    function _estimateKyberLarryAmount(uint256 ethAmount) internal view returns (uint256) {
        // Based on our analysis: KyberSwap gives ~1% more LARRY than Larry DEX
        // This is a simplified estimation - in production, call real Kyber quoter
        uint256 larryDexAmount = larryToken.getBuyLARRY(ethAmount);
        
        // Assume KyberSwap gives 1.01x more (this would come from real quoter)
        return (larryDexAmount * 10100) / 10000; // 1% more
    }
    
    /**
     * @notice Estimate ETH return from selling LARRY on KyberSwap
     * @dev This is a simplified estimation. In production, use real KyberSwap quoter
     * @param larryAmount LARRY amount to swap
     * @return Estimated ETH amount
     */
    function _estimateKyberEthReturn(uint256 larryAmount) internal view returns (uint256) {
        // Based on analysis: assume KyberSwap gives slightly less ETH than Larry DEX
        uint256 larryDexEthReturn = larryToken.LARRYtoETH(larryAmount);
        
        // Assume KyberSwap gives 0.5% less ETH when selling
        return (larryDexEthReturn * 9950) / 10000; // 0.5% less
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
     * @notice Withdraw protocol fees
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }
    
    /**
     * @notice Update contract owner
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
    
    /**
     * @notice Update token approvals if needed
     */
    function updateApprovals() external onlyOwner {
        larryToken.approve(KYBER_ROUTER, type(uint256).max);
        weth.approve(KYBER_ROUTER, type(uint256).max);
    }
    
    /**
     * @notice Simple Larry DEX round-trip for testing (no KyberSwap)
     */
    function executeSimpleRoundTrip() external payable {
        require(msg.value > 0, "Must send ETH");
        
        uint256 initialBalance = address(this).balance - msg.value;
        
        // Buy LARRY with ETH
        larryToken.buy{value: msg.value}(address(this));
        
        // Get LARRY balance
        uint256 larryBalance = larryToken.balanceOf(address(this));
        require(larryBalance > 0, "No LARRY received");
        
        // Sell LARRY back to ETH
        larryToken.sell(larryBalance);
        
        uint256 finalBalance = address(this).balance;
        
        // Send all ETH back to caller
        if (finalBalance > 0) {
            payable(msg.sender).transfer(finalBalance);
        }
        
        emit ArbitrageExecuted(
            msg.sender,
            msg.value,
            larryBalance,
            finalBalance > initialBalance ? finalBalance - initialBalance : 0,
            block.timestamp
        );
    }
    
    receive() external payable {}
}