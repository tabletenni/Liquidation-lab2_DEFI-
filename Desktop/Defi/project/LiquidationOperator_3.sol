//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

// ----------------------INTERFACE------------------------------


interface ILendingPool {
    
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT
    function transfer(address to, uint256 value) external returns (bool);
}

interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}


interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}


interface IUniswapV2Factory {

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}


interface IUniswapV2Pair {

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// ----------------------IMPLEMENTATION------------------------------

contract LiquidationOperator is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IUniswapV2Factory constant uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Pair immutable uniswapV2Pair_WETH_USDC; // Pool

    ILendingPool constant lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    address constant liquidationTarget = 0x63f6037d3e9d51ad865056BF7792029803b6eEfD;
    uint debt_USDC;

    // END TODO

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    constructor() {
        // TODO: (optional) initialize your contract

        uniswapV2Pair_WETH_USDC = IUniswapV2Pair(uniswapV2Factory.getPair(address(USDC), address(WETH))); // Pool
        debt_USDC = 8128956343;
        
        // END TODO
    }

    // TODO: add a `receive` function so that you can withdraw your WETH

    receive() external payable {}

    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // TODO: implement your liquidation logic

        // 0. security checks and initializing variables
        //    *** Your code here ***

        // 1. get the target user account data & make sure it is liquidatable
        
        uint256 totalCollateralETH;
        uint256 totalDebtETH;
        uint256 availableBorrowsETH;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
        (
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        ) = lendingPool.getUserAccountData(liquidationTarget);

        require(healthFactor < (10 ** health_factor_decimals), "Cannot liquidate; health factor must be below 1" );

        // 2. call flash swap to liquidate the target user


        uniswapV2Pair_WETH_USDC.swap(debt_USDC, 0, address(this), "$");
        uint collateral_WETH = WETH.balanceOf(address(this));
        
        console.log("collateral_WETH: %s", collateral_WETH);
        console.log("address:%s", USDC.balanceOf(address(this)));

        // 3. Convert the profit into ETH and send back to sender

        uint balance = WETH.balanceOf(address(this));
        WETH.withdraw(balance);
        payable(msg.sender).transfer(address(this).balance);

        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256 amount1,
        uint256,
        bytes calldata
    ) external override {
        // TODO: implement your liquidation logic

        // 2.0. security checks and initializing variables
        
        assert(msg.sender == address(uniswapV2Pair_WETH_USDC));
        (uint256 reserve_USDC_Pool1, uint256 reserve_WETH_Pool1, ) = uniswapV2Pair_WETH_USDC.getReserves(); // Pool

        // 2.1 liquidate the target user

        console.log(USDC.balanceOf(address(this)));
        
        uint debtToCover = amount1;
        USDC.approve(address(lendingPool), debtToCover);

        lendingPool.liquidationCall(address(WETH), address(USDC), liquidationTarget, debtToCover, false);
        uint collateral_WETH = WETH.balanceOf(address(this));

        // 2.2 repay

        uint repay_WETH = getAmountIn(debtToCover, reserve_WETH_Pool1, reserve_USDC_Pool1);
        WETH.transfer(address(uniswapV2Pair_WETH_USDC), repay_WETH);
         
       


        // END TODO
    }
}