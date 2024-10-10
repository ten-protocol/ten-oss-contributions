// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title ChuckALuck - A smart contract for playing Chuck-a-Luck
/// @author Assistant
/// @notice This contract allows players to play Chuck-a-Luck using TEN chain's features
/// @dev Utilizes TEN chain's private shared states and secure randomness
contract ChuckALuck {
    address public owner;
    uint256 public minBet;
    uint256 public maxBet;
    uint256 public houseBalance;
    
    private mapping(address => uint256) private playerBalances;

    enum BetType { Single, Field, AnyTriple, SpecificTriple }

    struct Bet {
        BetType betType;
        uint8 number;
        uint256 amount;
    }

    /// @notice Emitted when a player places a bet
    /// @param player The address of the player
    /// @param betType The type of bet placed
    /// @param number The number bet on (if applicable)
    /// @param amount The amount bet
    event BetPlaced(address indexed player, BetType indexed betType, uint8 number, uint256 amount);

    /// @notice Emitted when a game is resolved
    /// @param player The address of the player
    /// @param dice The results of the dice rolls
    /// @param winAmount The amount won (0 if loss)
    event GameResolved(address indexed player, uint8[3] dice, uint256 winAmount);

    /// @notice Emitted when a player deposits funds
    /// @param player The address of the player
    /// @param amount The amount deposited
    event Deposit(address indexed player, uint256 amount);

    /// @notice Emitted when a player withdraws funds
    /// @param player The address of the player
    /// @param amount The amount withdrawn
    event Withdrawal(address indexed player, uint256 amount);

    /// @notice Sets up the Chuck-a-Luck game with initial bet limits
    /// @param _minBet The minimum allowed bet
    /// @param _maxBet The maximum allowed bet
    constructor(uint256 _minBet, uint256 _maxBet) {
        owner = msg.sender;
        minBet = _minBet;
        maxBet = _maxBet;
    }

    /// @notice Ensures only the owner can call the function
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /// @notice Allows a player to deposit funds
    /// @dev Updates the player's balance and emits a Deposit event
    function deposit() public payable {
        playerBalances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Allows a player to withdraw funds
    /// @param amount The amount to withdraw
    /// @dev Checks for sufficient balance, updates the player's balance, and emits a Withdrawal event
    function withdraw(uint256 amount) public {
        require(playerBalances[msg.sender] >= amount, "Insufficient balance");
        playerBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /// @notice Allows a player to place a bet and play Chuck-a-Luck
    /// @param betType The type of bet being placed
    /// @param number The number being bet on (for Single bets)
    /// @param betAmount The amount being bet
    /// @dev Places the bet, rolls the dice, calculates winnings, and emits events
    function placeBet(BetType betType, uint8 number, uint256 betAmount) public {
        require(betAmount >= minBet && betAmount <= maxBet, "Bet amount out of range");
        require(playerBalances[msg.sender] >= betAmount, "Insufficient player balance");
        require(houseBalance >= betAmount * 30, "Insufficient house balance"); // Cover max payout

        if (betType == BetType.Single) {
            require(number >= 1 && number <= 6, "Invalid number for Single bet");
        } else if (betType == BetType.SpecificTriple) {
            require(number >= 1 && number <= 6, "Invalid number for Specific Triple bet");
        } else {
            require(number == 0, "Number should be 0 for Field or Any Triple bets");
        }

        playerBalances[msg.sender] -= betAmount;
        houseBalance += betAmount;

        emit BetPlaced(msg.sender, betType, number, betAmount);

        uint8[3] memory dice = rollDice();
        uint256 winAmount = calculateWinnings(betType, number, betAmount, dice);

        if (winAmount > 0) {
            require(houseBalance >= winAmount, "Insufficient house balance for payout");
            houseBalance -= winAmount;
            playerBalances[msg.sender] += winAmount;
        }

        emit GameResolved(msg.sender, dice, winAmount);
    }

    /// @notice Rolls three dice
    /// @return An array of three dice roll results
    /// @dev Uses TEN chain's block.difficulty for randomness
    function rollDice() private view returns (uint8[3] memory) {
        uint256 randomness = uint256(block.difficulty);
        uint8[3] memory dice;
        for (uint i = 0; i < 3; i++) {
            dice[i] = uint8((randomness % 6) + 1);
            randomness = uint256(keccak256(abi.encodePacked(randomness, i)));
        }
        return dice;
    }

    /// @notice Calculates the winnings for a bet
    /// @param betType The type of bet placed
    /// @param number The number bet on (if applicable)
    /// @param betAmount The amount bet
    /// @param dice The results of the dice rolls
    /// @return The amount won (0 if loss)
    function calculateWinnings(BetType betType, uint8 number, uint256 betAmount, uint8[3] memory dice) private pure returns (uint256) {
        if (betType == BetType.Single) {
            uint8 matches = 0;
            for (uint i = 0; i < 3; i++) {
                if (dice[i] == number) matches++;
            }
            return betAmount * matches;
        } else if (betType == BetType.Field) {
            uint8 sum = dice[0] + dice[1] + dice[2];
            if (sum < 8 || sum > 12) return betAmount;
        } else if (betType == BetType.AnyTriple) {
            if (dice[0] == dice[1] && dice[1] == dice[2]) return betAmount * 30;
        } else if (betType == BetType.SpecificTriple) {
            if (dice[0] == number && dice[1] == number && dice[2] == number) return betAmount * 30;
        }
        return 0;
    }

    /// @notice Allows a player to check their balance
    /// @return The current balance of the player
    function getBalance() public view returns (uint256) {
        return playerBalances[msg.sender];
    }

    /// @notice Allows the owner to set new minimum and maximum bet limits
    /// @param _minBet The new minimum bet
    /// @param _maxBet The new maximum bet
    /// @dev Only callable by the owner
    function setMinMaxBet(uint256 _minBet, uint256 _maxBet) public onlyOwner {
        minBet = _minBet;
        maxBet = _maxBet;
    }

    /// @notice Allows the owner to add funds to the house balance
    /// @dev Only callable by the owner, updates the house balance
    function addHouseBalance() public payable onlyOwner {
        houseBalance += msg.value;
    }

    /// @notice Allows the owner to withdraw funds from the house balance
    /// @param amount The amount to withdraw
    /// @dev Only callable by the owner, checks for sufficient balance
    function withdrawHouseBalance(uint256 amount) public onlyOwner {
        require(amount <= houseBalance, "Insufficient house balance");
        houseBalance -= amount;
        payable(owner).transfer(amount);
    }
}
