// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SideEntranceLenderPool} from "src/side-entrance/SideEntranceLenderPool.sol";
import {SideEntranceAttack} from "src/player-contracts/SideEntranceAttack.sol";

contract SideEntranceTest is Test {
    uint256 constant ETHER_IN_POOL = 1_000 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    SideEntranceLenderPool pool;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.deal(deployer, ETHER_IN_POOL);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        vm.startPrank(deployer);

        pool = new SideEntranceLenderPool();

        pool.deposit{value: ETHER_IN_POOL}();

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(address(pool).balance, ETHER_IN_POOL);

        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.startPrank(player);

        SideEntranceAttack attackContract = new SideEntranceAttack(
            address(pool)
        );
        attackContract.exploit();

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player has taken all tokens from the pool
        assertEq(address(pool).balance, 0);
        assertGt(player.balance, ETHER_IN_POOL);
    }
}
