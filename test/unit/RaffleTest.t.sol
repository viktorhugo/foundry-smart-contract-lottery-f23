// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Raffle } from "../../src/Raffle.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test{

    /* Events */
    event RaffleEntered(address indexed player);
    
    Raffle raffle;
    HelperConfig helperConfig;
    
    /* variables de estado */
    uint256 raffleEntranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 10 ether;
    
    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            raffleEntranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        // le damos algo de fondos al player
        console.log('================    setUp   ===========================');
        console.log('raffleEntranceFee', raffleEntranceFee);
        console.log('interval', interval);
        console.log('vrfCoordinator', vrfCoordinator);
        console.log('subscriptionId', subscriptionId);
        console.log('callbackGasLimit', callbackGasLimit);
        console.logBytes32(gasLane);
        console.log('===========================================');
        vm.deal(PLAYER, STARTING_USER_BALANCE); // le damos algo de fondos
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ///////////////////////////////
    //          enterRaffle
    //////////////////////////////
    function testRaffleRevertsWhenYourDontPayEnough() public {
        
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert( // se espera que se revierta por que en este punto el player no ha pagado la entrada
            Raffle.Raffle__NotEnoughtETHSent.selector
        );
        // Assert
        raffle.enterRaffle(); // se espera que se revierta por que en este punto el player no ha pagado la entrada
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public { // test 
        
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        raffle.enterRaffle{ value: raffleEntranceFee }(); // se espera que se pase la entrada
        address playerRecord = raffle.getPlayer(0);
        console.log('PLAYER', PLAYER);
        console.log('playerRecord', playerRecord);
        assert(playerRecord == PLAYER);
    }

    function testEmitsEventOnEntrance() public { // test vamos a estar esperando un emit event
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        console.log('address(raffle)', address(raffle));
        console.log('PLAYER', PLAYER);
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
    }

    function testCanEnterWhenRaffleIsCalculating() public { // testear si podemos entrar cuando el raffle esta calculando el ganador
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        raffle.enterRaffle{ value: raffleEntranceFee }();
        console.log('block.timestamp', block.timestamp);
        console.log('block.timestamp + interval + 1',block.timestamp + interval + 1);
        vm.warp(block.timestamp + interval + 1);  
        vm.roll(block.number +1 ); // desplazamiento de los puntos
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
    }

}