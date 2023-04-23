// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DamnValuableToken} from "src/DamnValuableToken.sol";
import {DamnValuableNFT} from "src/DamnValuableNFT.sol";
import {FreeRiderNFTMarketplace} from "src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecovery} from "src/free-rider/FreeRiderRecovery.sol";
import {FreeRiderAttack} from "src/player-contracts/FreeRiderAttack.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract FreeRiderTest is Test {
    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 constant NFT_PRICE = 15 ether;
    uint256 constant AMOUNT_OF_NFTS = 6;
    uint256 constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;

    uint256 constant BOUNTY = 45 ether;

    // Initial reserves for the Uniswap v2 pool
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000 ether;
    uint256 constant UNISWAP_INITIAL_WETH_RESERVE = 9_000 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");
    address devs = makeAddr("DEVS");

    DamnValuableNFT nft;
    DamnValuableToken token;
    IWETH9 weth;

    IUniswapV2Factory uniswapFactory;
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Pair uniswapPair;

    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery devsContract;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        vm.warp(1_234_567_890);

        vm.deal(
            deployer,
            UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE
        );
        vm.deal(devs, BOUNTY);

        // Player starts with limited ETH balance
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        vm.startPrank(deployer);

        // Deploy WETH
        weth = IWETH9(deployCode("src/build-uniswap-v2/WETH9.json"));
        vm.label(address(weth), "WETH");

        // Deploy token to be traded against WETH in Uniswap v2
        token = new DamnValuableToken();

        // Create Uniswap Factory and Router
        uniswapFactory = IUniswapV2Factory(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Factory.json",
                abi.encode(address(0))
            )
        );
        vm.label(address(uniswapFactory), "UniswapFactory");

        uniswapRouter = IUniswapV2Router02(
            deployCode(
                "src/build-uniswap-v2/UniswapV2Router02.json",
                abi.encode(address(uniswapFactory), address(weth))
            )
        );
        vm.label(address(uniswapRouter), "UniswapRouter");

        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // The function takes care of deploying the pair automatically
        token.approve(address(uniswapRouter), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapRouter.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token),
            UNISWAP_INITIAL_TOKEN_RESERVE,
            0,
            0,
            deployer,
            block.timestamp * 2
        );

        // Get a reference to the created Uniswap pair
        uniswapPair = IUniswapV2Pair(
            uniswapFactory.getPair(address(token), address(weth))
        );
        vm.label(address(uniswapPair), "UniswapPair");

        // Deploy the marketplace and get the associated ERC721 token
        // The marketplace will automatically mint AMOUNT_OF_NFTS to the deployer (see `FreeRiderNFTMarketplace::constructor`)
        marketplace = new FreeRiderNFTMarketplace{
            value: MARKETPLACE_INITIAL_ETH_BALANCE
        }(AMOUNT_OF_NFTS);

        // Deploy NFT contract
        nft = marketplace.token();

        // Approve the marketplace to trade them
        nft.setApprovalForAll(address(marketplace), true);

        // Open offers in the marketplace
        uint256[] memory ids = new uint256[](6);
        uint256[] memory prices = new uint256[](6);
        for (uint256 i; i < AMOUNT_OF_NFTS; i++) {
            ids[i] = i;
            prices[i] = NFT_PRICE;
        }
        marketplace.offerMany(ids, prices);

        vm.stopPrank();

        // Deploy devs' contract, adding the player as the beneficiary
        vm.prank(devs);
        devsContract = new FreeRiderRecovery{value: BOUNTY}(
            player,
            address(nft)
        );
    }

    function test_SetUpState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        assertEq(uniswapPair.token0(), address(token));
        assertEq(uniswapPair.token1(), address(weth));
        assertGt(uniswapPair.balanceOf(deployer), 0);

        // ownership renounced
        assertEq(nft.owner(), address(0));
        assertEq(nft.rolesOf(address(marketplace)), nft.MINTER_ROLE());

        // Ensure deployer owns all minted NFTs
        for (uint256 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(nft.ownerOf(id), deployer);
        }

        assertEq(marketplace.offersCount(), 6);
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */

        vm.startPrank(player, player);

        FreeRiderAttack attackContract = new FreeRiderAttack(
            address(uniswapPair),
            address(weth),
            address(marketplace),
            address(devsContract)
        );
        attackContract.exploit(NFT_PRICE);

        vm.stopPrank();

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // The devs extract all NFTs from its associated contract
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            vm.prank(devs);
            nft.transferFrom(address(devsContract), devs, tokenId);
            assertEq(nft.ownerOf(tokenId), devs);
        }

        // Exchange must have lost NFTs and ETH
        assertEq(marketplace.offersCount(), 0);
        assertLt(address(marketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);

        // Player must have earned all ETH
        assertGt(player.balance, BOUNTY);
        assertEq(address(devsContract).balance, 0);
    }
}
