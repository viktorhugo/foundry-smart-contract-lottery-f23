// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Raffle } from "../../src/Raffle.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Test, console, Vm } from "forge-std/Test.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

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
            link,
            
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

    ///////////////////////////////
    //          checkUpkeep
    /////////////////////////////

    function testCheckUpKeepReturnsFalseIfItHasNobalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // aumentar el tiempo
        vm.roll(block.number +1 );
        console.log('block.timestamp + interval + 1', block.timestamp + interval + 1);
        console.log('block.timestamp-warp', block.number + 1);
        // Act
        (bool upkeep, ) = raffle.checkUpkeep("");
        
        // Assert
        assert(!upkeep);
    }

    // deberia devolver false si el raffle esta abierto
    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        // para que el raffle no este abierto tenemos que entrar al perfomUpkeep y debe estar en modo CALCULATING
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
        vm.warp(block.timestamp + interval + 1); // aumentar el tiempo
        vm.roll(block.number +1 );
        raffle.performUpkeep("");
        console.log('block.timestamp + interval + 1',block.timestamp + interval + 1);
        console.log('block.timestamp-warp', block.number + 1);
        // Act
        (bool upkeep, ) = raffle.checkUpkeep("");
        assert(upkeep == false);
        // Assert
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed () public { //devuelve falso si no ha pasado suficiente tiempo
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
        // Act
        (bool upkeep, ) = raffle.checkUpkeep("");
        assert(upkeep == false);
        // Assert
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood () public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
        vm.warp(block.timestamp + interval + 1); // aumentar el tiempo
        vm.roll(block.number +1 );
        // Act
        (bool upkeep, ) = raffle.checkUpkeep("");
        assert(upkeep == true);
        // Assert
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: raffleEntranceFee }();
        vm.warp(block.timestamp + interval + 1); // aumentar el tiempo
        vm.roll(block.number +1 );
        _;
    }


    function testPerformUpkeepCanOnlRunIfCheckUpKeepIsTrue() public raffleEnteredAndTimePassed{
        // Arrange
        console.log('block.timestamp + interval + 1', block.timestamp + interval + 1);
        console.log('block.timestamp-warp', block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 curretBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkkepNotNeeded.selector,
                curretBalance, 
                numPlayers, 
                raffleState
            )
        );
        raffle.performUpkeep(""); // estamos esperando un revert con el siguiente error (Raffle__UpkkepNotNeeded)
    }

    // que pasa si nesecito realizar una prueba utlizando la salida de un evento ?
    // Recuerde nuestros smart contracts no pueden acceder a los eventos 

    function testPerformUpkeepUpdatesRaffleStateAnEmitsRequestId() public raffleEnteredAndTimePassed{
        // Arrange
        
        // Act
        // vamos a capturar el requestId de la solicitud
        vm.recordLogs(); // Le dice a la VM que comience a registrar todos los eventos emitidos. Para acceder a ellos, utilice getRecordedLogs.
        raffle.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // ahora podemos obtener el requestId de la lista de eventos
        bytes32 requestId = entries[1].topics[1];
        console.log('requestId', uint256(requestId));
        Raffle.RaffleState rstate = raffle.getRaffleState();
        console.log('rstate', uint256(rstate));
        
        assert(uint256(requestId) != 0);
        assert(uint256(rstate) == 1);
    }

     //////////////////////////////////////////////////
    //          fulfillRandomWords                   //
    ///////////////////////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    //  prueba para cumplir con palabras aleatorias solo se puede llamar despues de realizar el performUpkeep
    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId ) public raffleEnteredAndTimePassed  skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle) // contract addres
        );
        // Act 
        // lo que sucedera ahora es que cuando se ejecute esta prueba Foundry creara y llamara a esta prueba muchas veces con 
        // muchos nuemros aleatorios
    }

    function testFulFillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork {
        // Arrange
        uint256 additionalEntrants = 5; // entrada adicional 
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address participant = address(uint160(i)); //esto genera una listadireccion basada en el indice
            hoax(participant, STARTING_USER_BALANCE); // truco para darle un ether a cada usuario
            raffle.enterRaffle{ value: raffleEntranceFee }(); // vamos a particiar en el sorteo haciendonos pasar por un player que realmente tiene ether
        }

        uint256 prize = raffleEntranceFee * (additionalEntrants + 1);

        // Act
        vm.recordLogs(); // Le dice a la VM que comience a registrar todos los eventos emitidos. Para acceder a ellos, utilice getRecordedLogs.
        raffle.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // ahora podemos obtener el requestId de la lista de eventos
        bytes32 requestId = entries[1].topics[1];
        
        uint256 previousTimeStamp = raffle.getLastTimestamp();
        console.log('previousTimeStamp', previousTimeStamp);

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle) // contract addres
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); // 0 = OPEN
        assert(raffle.getRecentWinner() != address(0)); // 0 = OPEN
        assert(raffle.getTotalParticipants() == 0);
        assert(previousTimeStamp < raffle.getLastTimestamp() );
        console.log('previousTimeStamp', previousTimeStamp, 'raffle.getLastTimestamp()', raffle.getLastTimestamp());
        console.log('raffle.getRecentWinner().balance', raffle.getRecentWinner().balance);
        console.log('STARTING_USER_BALANCE', STARTING_USER_BALANCE);
        console.log('prize', prize);
        console.log('raffleEntranceFee', raffleEntranceFee);
        console.log('STARTING_USER_BALANCE + prize - raffleEntranceFee', STARTING_USER_BALANCE + prize - raffleEntranceFee);
        assert(raffle.getRecentWinner().balance == (STARTING_USER_BALANCE + prize - raffleEntranceFee));
    }
}