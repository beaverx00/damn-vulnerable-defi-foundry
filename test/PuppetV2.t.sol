// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface IUniswapV2Pair {
    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Factory {
    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IUniswapV2Router {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function addLiquidityEth(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

interface IPuppetV2Pool {
    function borrow(uint256 borrowAmount) external;

    function calculateDepositOfWETHRequired(uint256 tokenAmount)
        external
        view
        returns (uint256);
}

contract PuppetV2Test is Test {
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 100 ether;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 10 ether;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 10_000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 20 ether;

    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    DamnValuableToken token;
    IWETH weth;

    IUniswapV2Factory uniswapFactory;
    IUniswapV2Router uniswapRouter;
    IUniswapV2Pair uniswapExchange;
    IPuppetV2Pool lendingPool;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.warp(1_234_567_890);

        vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        vm.startPrank(deployer);

        // Deploy token to be traded
        token = new DamnValuableToken();

        weth = IWETH(deployCode("src/build-uniswap-v2/WETH9.json"));
        vm.label(address(weth), "WETH");

        // Create Uniswap Factory and Router
        uniswapFactory = IUniswapV2Factory(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Factory.json",
                abi.encode(address(0))
            )
        );
        vm.label(address(uniswapFactory), "UniswapFactory");

        console.log(uniswapFactory.feeTo());
        uniswapRouter = IUniswapV2Router(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Router02.json",
                abi.encode(address(uniswapFactory), address(weth))
            )
        );
        console.log(uniswapRouter.factory(), uniswapRouter.WETH());
        vm.label(address(uniswapRouter), "UniswapRouter");

        // Create Uniswap pair against and add Liquidity
        token.approve(address(uniswapRouter), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapRouter.addLiquidityEth{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token),
            UNISWAP_INITIAL_TOKEN_RESERVE,
            0,
            0,
            deployer,
            block.timestamp * 2
        );
        uniswapExchange = IUniswapV2Pair(
            uniswapFactory.getPair(address(token), address(weth))
        );

        // Deploy the lending pool
        lendingPool = IPuppetV2Pool(
            deployCode(
                "src/puppet-v2/PuppetV2Pool.json",
                abi.encode(
                    address(weth),
                    address(token),
                    address(uniswapExchange),
                    address(uniswapFactory)
                )
            )
        );
        vm.label(address(lendingPool), "LendingPool");

        // Setup initial token balances of pool and player accounts
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        assertGt(uniswapExchange.balanceOf(deployer), 0);

        // Check pool's been correctly setup
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(1 ether),
            0.3 ether
        );
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            ),
            300_000 ether
        );
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */

        vm.startPrank(player);

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(lendingPool)), 0);
        assertGe(token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    }
}
