// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function WETH() external pure returns (address);
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract EtherToUSDC {
    address public owner;
    IUniswapV2Router public immutable uniswapRouter;
    address public immutable USDC;
    uint256 public lastSwapTime;
    uint256 public constant SWAP_INTERVAL = 1 hours;

    event EtherSwapped(uint256 ethAmount, uint256 usdcReceived);
    event FundsWithdrawn(address indexed recipient, uint256 ethAmount, uint256 usdcAmount);

    constructor(address _router, address _usdc) {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router(_router);
        USDC = _usdc;
        lastSwapTime = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    receive() external payable {
        swapETHForUSDC(msg.value);
    }

    function swapETHForUSDC(uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");
        
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = USDC;

        uint256 initialUSDCBalance = IERC20(USDC).balanceOf(address(this));
        
        uniswapRouter.swapExactETHForTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp + 15 minutes
        );

        uint256 newUSDCBalance = IERC20(USDC).balanceOf(address(this));
        uint256 usdcReceived = newUSDCBalance - initialUSDCBalance;
        
        lastSwapTime = block.timestamp;
        emit EtherSwapped(amount, usdcReceived);
    }

    function executeScheduledSwap() external {
        require(block.timestamp >= lastSwapTime + SWAP_INTERVAL, "Swap interval not reached");
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            swapETHForUSDC(ethBalance);
        }
    }

    function withdrawFunds(uint256 ethAmount, uint256 usdcAmount) external onlyOwner {
        if (ethAmount > 0) {
            require(address(this).balance >= ethAmount, "Insufficient Ether balance");
            payable(owner).transfer(ethAmount);
        }
        
        if (usdcAmount > 0) {
            uint256 usdcBal = IERC20(USDC).balanceOf(address(this));
            require(usdcBal >= usdcAmount, "Insufficient USDC balance");
            require(IERC20(USDC).transfer(owner, usdcAmount), "USDC transfer failed");
        }
        
        emit FundsWithdrawn(owner, ethAmount, usdcAmount);
    }

    function getBalances() external view returns (uint256 ethBalance, uint256 usdcBalance) {
        ethBalance = address(this).balance;
        usdcBalance = IERC20(USDC).balanceOf(address(this));
    }

    function timeUntilNextSwap() external view returns (uint256) {
        if (block.timestamp >= lastSwapTime + SWAP_INTERVAL) {
            return 0;
        }
        return (lastSwapTime + SWAP_INTERVAL) - block.timestamp;
    }
}