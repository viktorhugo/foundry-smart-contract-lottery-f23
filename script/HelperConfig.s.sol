// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        uint256 raffleEntranceFee;
        uint256 interval;
        address vrfCoordinator; 
        bytes32 gasLane; 
        uint64 subscriptionId; 
        uint32 callbackGasLimit;
        address link; 
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if ( block.chainid == 11155111 ) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if ( block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateGanacheEthConfig();
        }
    }

    function getSepoliaEthConfig () public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            raffleEntranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // Update this with our SubID
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789 // 500,000 GAAS
        });
    }

    function getOrCreateGanacheEthConfig () public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,// tarifa fija base 
            gasPriceLink// gas pirce (cuanto se paga por cada pieza adicional de gas que se usa ) 
        );
        vm.stopBroadcast();

        LinkToken linkToken = new LinkToken();

        return NetworkConfig({
            raffleEntranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // our script will add this
            callbackGasLimit: 500000, // 500,000 GAAS
            link: address(linkToken)
        });
    }

    function getMainnetEthConfig () public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            raffleEntranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gasLane: 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92, // 500 gwei Clave Hash
            subscriptionId: 0, // Update this with our SubID
            callbackGasLimit: 500000, // 500,000 GAAS
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
        });
    }

}