// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Slot Machine Contract
/// @notice Implements a simple slot machine game on Ethereum
contract SlotMachine {
    /// @notice Owner of the contract
    address public owner;

    /// @notice Event emitted when a bet is placed
    event BetPlaced(address indexed player, uint256 betAmount);

    /// @notice Event emitted when the spin result is determined
    event SpinResult(address indexed player, uint256[3] spinResult, uint256 payout);
    event SpinOutcome(address indexed player, bool won, uint256 payout);


    /// @notice Fixed array of 10 symbols represented as integers (0-9)
    uint8[10] public symbols;
    uint256 private seed;

    /// @notice Indicates if the contract is paused
    bool public contractPaused = false;

    /// @notice Ensures that only the contract owner can call a function
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /// @notice Ensures that the function can only be called when the contract is not paused
    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    /// @notice Contract constructor that sets the initial owner and the symbols array
    constructor() {
        owner = msg.sender;
        symbols = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    }

    /// @notice Allows a player to spin the reels after placing a bet
    /// @dev Requires the sent value to match the fixed bet amount
    function spin() external payable whenNotPaused {
        require(msg.value == 0.0443 ether, "Invalid bet amount");
        emit BetPlaced(msg.sender, msg.value);
        require(address(this).balance >= 44300000000000000, "Not enough balance to pay out");
        
        uint256[3] memory result;
        for (uint256 i = 0; i < 3; i++) {
            result[i] = symbols[random() % 10];
        }

        uint256 payout = calculatePayout(result);
        bool hasWon = payout > 0;

        if (hasWon) {
            payable(msg.sender).transfer(payout);
        }

/*
        if (payout > 0) {
            // Attempt to send the payout
            (bool sent, ) = payable(msg.sender).call{value: payout}("");
            if (!sent) {
                // Handle failed send, e.g., wrap to WETH and transfer
                // This will require additional logic and integration with a WETH contract
            }
        }
*/
        emit SpinResult(msg.sender, result, payout);
        emit SpinOutcome(msg.sender, hasWon, payout);
    }

    /// @notice Generates a pseudo-random number
    /// @return A pseudo-random number
    function random() private returns (uint256) {
        seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, seed)));
        return (seed % 100000);
    }

    /// @notice Calculates the payout based on the spin result
    /// @param result The result of the spin
    /// @return The amount of payout
    function calculatePayout(uint256[3] memory result) private pure returns (uint256) {
        uint8[3][5] memory winningCombinations = [
        [0, 0, 0], // Three of the same symbol
        [7, 7, 7], // Three 7s
        [9, 9, 0], // Two Wild symbols and one of any symbol
        [0, 9, 9], // One of any symbol, followed by two Wild symbols
        [8, 8, 8] // Three Diamond symbols
        ];

    uint16[5] memory basePayouts = [1000, 500, 200, 100, 50];

    for (uint256 i = 0; i < 5; i++) {
        if (result[0] == winningCombinations[i][0] &&
            result[1] == winningCombinations[i][1] &&
            result[2] == winningCombinations[i][2]) {
            return (basePayouts[i] * 95) / 100; // 5% house edge
        }
    }

    return 0; // No winning combination
}

/// @notice Allows the owner to fund the contract
/// @dev Requires that the sender is the owner and the sent value is greater than 0
function fundContract() external payable onlyOwner {
    require(msg.value > 0, "Amount must be greater than 0");
}

/// @notice Allows the owner to withdraw funds from the contract
/// @param amount The amount to withdraw
/// @dev Requires that the sender is the owner and there are sufficient funds
function withdrawFunds(uint256 amount) external onlyOwner {
    require(address(this).balance >= amount, "Not enough balance to withdraw");
    payable(owner).transfer(amount);
}

/// @notice Pauses the contract, preventing spins
/// @dev Can only be called by the owner
function pauseContract() external onlyOwner {
    contractPaused = true;
}

/// @notice Unpauses the contract, allowing spins
/// @dev Can only be called by the owner
function unpauseContract() external onlyOwner {
    contractPaused = false;
}

/// @notice Returns the current balance of the contract
/// @return The balance of the contract
function getContractBalance() external view returns (uint256) {
    return address(this).balance;
}
}
