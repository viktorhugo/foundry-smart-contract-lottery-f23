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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
* @title  A sample Rafflec contract
* @author Victor Mosquera
* @notice This contract is for creating a sample raffle
* @dev Implementd Chainlink VRFv2
*/
contract Raffle {
    error Raffle__NotEnoughtETHSent();

    uint256 private immutable i_raffleEntranceFee;
    // nesecitamos una estructura de seguimiento para todas las personas que han participado en la loteria
    address payable[] private s_participants;

    constructor(uint256 raffleEntranceFee) {
        i_raffleEntranceFee = raffleEntranceFee;
    }

    // queremos que la gente pague por un boleto para participar en el sorteo con un precio de entrada
    function enterRaffle() external payable {
        // check raffleEntranceFee
        if (msg.value < i_raffleEntranceFee) revert Raffle__NotEnoughtETHSent();
        // add participant to array
        s_participants.push(payable(msg.sender));
        // 1. make migration easier
        // 2. make frontend indexing easier
    }

    function pickWinner() public {
        
    }

    /** Getter function */

    function getRaffleEntraceFee() public view returns (uint256) {
        return i_raffleEntranceFee;
    }
    
}
