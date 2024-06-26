// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is  Script {

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        ( , , address vrfCoordinator, , , , ,uint256 deployerKey ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
        console.log("creating subscription on chainId:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        console.log("Your subscriptionId: ", subscriptionId);
        console.log(" Please update subscriptionId in HelperConfig.s.sol");
        vm.stopBroadcast();
        return subscriptionId;
    } 
}


contract FundSubscription is  Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public  {
        
        HelperConfig helperConfig = new HelperConfig();
        ( 
            , 
            , 
            address vrfCoordinator, 
            , 
            uint64 subscriptionId, 
            , 
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        // vamos a nesecitar el link token 
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address link, uint256 deployerKey) public {
        console.log("Funded subscriptionId: ", subscriptionId);
        console.log("Funded VRFcoordinator: ", vrfCoordinator);
        console.log("Funding subscription on chainId:", block.chainid);

        // si estamos en una cadena local esto significa que tenemos un mock implementado
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken linkToken = LinkToken(link);
            linkToken.transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is  Script {
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffle);
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        ( 
            , 
            , 
            address vrfCoordinator, 
            , 
            uint64 subscriptionId, 
            , 
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    // ahora nuestra configuracion es totalmente inteligente como para saber si estamos en una red local o maintest o mainnet
    function addConsumer(address raffle, address vrfCoordinator, uint64 subscriptionId, uint256 deployerKey) public {
        console.log("Adding consumer CONTRACT:", raffle);
        console.log("Using coordinator :", vrfCoordinator);
        console.log("SubscriptionId :", subscriptionId);
        console.log("On chainId :", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, raffle);
        vm.stopBroadcast();
    }
}