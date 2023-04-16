// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";
import {TrusterLenderPool} from "src/truster/TrusterLenderPool.sol";
import {TrusterAttack} from "src/player-contracts/TrusterAttack.sol";

contract TrusterTest is Test {
    uint256 constant TOKENS_IN_POOL = 1_000_000 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    DamnValuableToken token;
    TrusterLenderPool pool;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.startPrank(deployer);

        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);

        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(address(pool.token()), address(token));

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);

        assertEq(token.balanceOf(player), 0);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.startPrank(player);

        TrusterAttack attackContract = new TrusterAttack(address(pool));
        attackContract.exploit();

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
