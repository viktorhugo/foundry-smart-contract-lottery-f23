// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// ESTAMOS CONDIFICANDO UN PATRON DE DISEÑO LLAMADO CHEX EFFECTS INTERACTIONS (C.E.I)

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import { console }  from "forge-std/Test.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
* @title  A sample Rafflec contract
* @author Victor Mosquera
* @notice This contract is for creating a sample raffle
* @dev Implementd Chainlink VRFv2
*/
contract Raffle is VRFConsumerBaseV2 { 
    error Raffle__NotEnoughtETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkkepNotNeeded(
        uint256 balance,
        uint256 numParticipants,
        uint256 raffleState
    );


    /** Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMBER_WORDS = 1;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_raffleEntranceFee;
    uint256 private immutable i_interval; // intervalo de tiempo entre sorteos in seconds
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    // nesecitamos una estructura de seguimiento para todas las personas que han participado en la loteria
    address payable[] private s_participants;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint256 raffleEntranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint64 subscriptionId, 
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2( vrfCoordinator) { // pass vrfCoordinator constructor
        i_raffleEntranceFee = raffleEntranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // queremos que la gente pague por un boleto para participar en el sorteo con un precio de entrada
    function enterRaffle() external payable {
        // check raffleEntranceFee
        if (msg.value < i_raffleEntranceFee) revert Raffle__NotEnoughtETHSent();
        // check if raffle is open
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();
        // add participant to array
        s_participants.push(payable(msg.sender));
        // cada que un usuario pague por un boleto, se agrega a la lista de participantes y se debe emitir un evento
        // 1. make migration easier (update contract)
        // 2. make frontend indexing easier
        emit RaffleEntered(msg.sender); // emit event
    }


    /**
     * 
     * @dev this is the function that the Chailink Automation nodes call
     * to see if it's time to perform a upkeep.
     * 1. the time interval has passed betwenn raffle runs.
     * 2. the raffle is in OPEN state
     * 3. THE contract has ETH (aka, Players)
     * 4. (Implicitly) The subscription is funded with LINK
     */
    // when is the winner suppoded to be picked
    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // comprobar que si ha pasado el tiempo suficiente
        bool hasTimePass = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasPlayers = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (hasTimePass && isOpen && hasPlayers && hasBalance);
        
        return (upkeepNeeded, /* performData */"0x0");
    }

    
    function performUpkeep(bytes calldata /* performData */) external {
        // check checkUpkeep
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle__UpkkepNotNeeded(
            address(this).balance,
            s_participants.length,
            uint256(s_raffleState)
        );
        //set raffle state
        s_raffleState = RaffleState.CALCULATING;
        // Solo seremos Nosotros de solicitar el ganador
        // vamos hacer una solicitud al nodo de chainlink para que nos de un numero aleatorio
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // solicita palabras aleatorias
            i_gasLane, // keyHash =>gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit, // MAX GAS
            NUMBER_WORDS // numero de numeros aleatorios que queremos
        );
        
    }
    
    // get a random number
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords ) internal override {
        // ahora que tenemos la lista de numeros aleatorio, qeuremos elegir un ganador del array de participantes

        // ======== Cheks ========
        // ======== Effects (afectamos nuestro contrato) ========
        uint256 winnerIndex = randomWords[0] % s_participants.length;
        address payable winner = s_participants[winnerIndex];
        s_recentWinner = winner;
        //set raffle state
        s_raffleState = RaffleState.OPEN;
        // nesecitamos restablecer el array de participantes para que comience un nuevo juego
        s_participants = new address payable[](0);
        // empesar de nuevo el tiempo de juego
        s_lastTimeStamp = block.timestamp;
        // emitir el ganador
        emit PickedWinner(s_recentWinner);

        // ======== Interactions (interactuamos con otros contratos) ========
        // le daremos el saldo total del contrato al ganador
        ( bool success, ) = s_recentWinner.call{ value: address(this).balance }("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }



    /** Getter function */

    function getRaffleEntraceFee() public view returns (uint256) {
        return i_raffleEntranceFee;
    }
    
}


//  podemos rastrear el bloque actual y el tiempo transcurrido comparandolo con el intervalo y la ultima vez que se eligio un ganador.
// block.timestamp => marca del tiempo actual ejemplo 1000 
// lastTimeStamp => la ultima instancia que tomamos fue de 500
// i_interval fue de 600
// block.timestamp - s_lastTimeStamp > i_interval;
// 1000 - 500 = 500 > 600 = false : no hay sufuciente tiempo para elegir un ganador
// 1200 - 500 = 700 > 600 = true : hay sufuciente tiempo para elegir un ganador
// if ((block.timestamp - s_lastTimeStamp) <= i_interval) {
//     revert("Not enough time has passed since the last winner was selected");
// }
