// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {FlashLoanerPool} from "src/the-rewarder/FlashLoanerPool.sol";
import {TheRewarderPool} from "src/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "src/the-rewarder/RewardToken.sol";
import {AccountingToken} from "src/the-rewarder/AccountingToken.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";
import {TheRewarderAttack} from "src/player-contracts/TheRewarderAttack.sol";

contract TheRewarderTest is Test {
    uint256 constant TOKENS_IN_LENDER_POOL = 1_000_000 ether;
    uint256 constant DEPOSIT_AMOUNT = 100 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    address alice = makeAddr("ALICE");
    address bob = makeAddr("BOB");
    address charlie = makeAddr("CHARLIE");
    address david = makeAddr("DAVID");
    address[] users = [alice, bob, charlie, david];

    DamnValuableToken liquidityToken;
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    AccountingToken accountingToken;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.startPrank(deployer);

        liquidityToken = new DamnValuableToken();
        flashLoanPool = new FlashLoanerPool(address(liquidityToken));

        liquidityToken.transfer(address(flashLoanPool), TOKENS_IN_LENDER_POOL);

        rewarderPool = new TheRewarderPool(address(liquidityToken));
        rewardToken = rewarderPool.rewardToken();
        accountingToken = rewarderPool.accountingToken();

        vm.stopPrank();

        for (uint256 i; i < users.length; i++) {
            vm.prank(deployer);
            liquidityToken.transfer(users[i], DEPOSIT_AMOUNT);

            vm.prank(users[i]);
            liquidityToken.approve(address(rewarderPool), DEPOSIT_AMOUNT);

            vm.prank(users[i]);
            rewarderPool.deposit(DEPOSIT_AMOUNT);
        }

        // Advance time 5 days so that depositors can get rewards
        skip(5 days);

        // Each depositor gets reward tokens
        for (uint256 i; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
        }
    }

    function test_SetUpState() public {
        assertEq(accountingToken.owner(), address(rewarderPool));

        uint256 minterRole = accountingToken.MINTER_ROLE();
        uint256 snapshotRole = accountingToken.SNAPSHOT_ROLE();
        uint256 burnerRole = accountingToken.BURNER_ROLE();
        assertTrue(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                minterRole | snapshotRole | burnerRole
            )
        );

        for (uint256 i; i < users.length; i++) {
            assertEq(accountingToken.balanceOf(users[i]), DEPOSIT_AMOUNT);
        }
        assertEq(accountingToken.totalSupply(), DEPOSIT_AMOUNT * users.length);

        /**
         * Some assertions are omitted, but they don't interfere with challenge
         */

        uint256 rewardsInRound = rewarderPool.REWARDS();
        for (uint256 i; i < users.length; i++) {
            assertEq(
                rewardToken.balanceOf(users[i]),
                rewardsInRound / users.length
            );
        }

        assertEq(rewardToken.totalSupply(), rewardsInRound);

        // Player starts with zero DVT tokens in balance
        assertEq(liquidityToken.balanceOf(player), 0);

        // Two rounds must have occurred so far
        assertEq(rewarderPool.roundNumber(), 2);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.startPrank(player);

        TheRewarderAttack attackContract = new TheRewarderAttack(
            address(flashLoanPool),
            address(rewarderPool)
        );

        skip(5 days);

        attackContract.exploit();

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Only one round must have taken place
        assertEq(rewarderPool.roundNumber(), 3);

        // Users should get neglegible rewards this round
        for (uint256 i; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();

            uint256 userRewards = rewardToken.balanceOf(users[i]);
            uint256 userDelta = userRewards -
                (rewarderPool.REWARDS() / users.length);
            assertLt(userDelta, 10**16);
        }

        // Rewards must have been issued to the player account
        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        uint256 playerRewards = rewardToken.balanceOf(player);
        assertGt(playerRewards, 0);

        // The amount of rewards earned should be closed to total available amount
        uint256 playerDelta = rewarderPool.REWARDS() - playerRewards;
        assertLt(playerDelta, 10**17);

        // Balance of DVT tokens in player and lending pool hasn't changed
        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(
            liquidityToken.balanceOf(address(flashLoanPool)),
            TOKENS_IN_LENDER_POOL
        );
    }
}
