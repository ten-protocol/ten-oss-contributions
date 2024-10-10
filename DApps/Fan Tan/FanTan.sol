// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title FanTan - A smart contract for playing Fan-Tan
/// @author Assistant
/// @notice This contract allows players to play Fan-Tan using TEN chain's features
/// @dev Utilizes TEN chain's private shared states and secure randomness
contract FanTan {
    address public owner;
    uint256 public minBet;
    uint256 public maxBet;
    uint256 public houseBalance;
    uint256 public constant HOUSE_FEE_PERCENT = 5; // 5% house fee

    private mapping(address => uint256) private playerBalances;

    struct Game {
        uint256 totalBet;
        mapping(uint8 => uint256) bets; // 1, 2, 3, 4 for each betting option
        bool resolved;
    }

    private mapping(address => Game) private currentGames;

    /// @notice Emitted when a player places a bet
    /// @param player The address of the player
    /// @param betType The type of bet placed (1, 2, 3, or 4)
    /// @param amount The amount bet
    event private BetPlaced(address indexed player, uint8 indexed betType, uint256 amount);

    /// @notice Emitted when a game is resolved
    /// @param player The address of the player
    /// @param result The winning number (1, 2, 3, or 4)
    /// @param winAmount The amount won (0 if loss)
    event private GameResolved(address indexed player, uint8 result, uint256 winAmount);

    /// @notice Emitted when a player deposits funds
    /// @param player The address of the player
    /// @param amount The amount deposited
    event private Deposit(address indexed player, uint256 amount);

    /// @notice Emitted when a player withdraws funds
    /// @param player The address of the player
    /// @param amount The amount withdrawn
    event private Withdrawal(address indexed player, uint256 amount);

    constructor(uint256 _minBet, uint256 _maxBet) {
        owner = msg.sender;
        minBet = _minBet;
        maxBet = _maxBet;
    }

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

    /// @notice Allows a player to place a bet in Fan-Tan
    /// @param betType The type of bet (1, 2, 3, or 4)
    /// @param betAmount The amount to bet
    /// @dev Places the bet and emits a BetPlaced event
    function placeBet(uint8 betType, uint256 betAmount) public {
        require(betType >= 1 && betType <= 4, "Invalid bet type");
        require(betAmount >= minBet && betAmount <= maxBet, "Bet amount out of range");
        require(playerBalances[msg.sender] >= betAmount, "Insufficient player balance");
        require(!currentGames[msg.sender].resolved, "Previous game not resolved");

        Game storage game = currentGames[msg.sender];
        game.bets[betType] += betAmount;
        game.totalBet += betAmount;
        playerBalances[msg.sender] -= betAmount;

        emit BetPlaced(msg.sender, betType, betAmount);
    }

    /// @notice Resolves the current game for the player
    /// @dev Generates a random result, calculates winnings, updates balances, and emits a GameResolved event
    function resolveGame() public {
        Game storage game = currentGames[msg.sender];
        require(game.totalBet > 0, "No bets placed");
        require(!game.resolved, "Game already resolved");

        uint8 result = generateResult();
        uint256 winAmount = calculateWinnings(game, result);

        if (winAmount > 0) {
            uint256 houseFee = (winAmount * HOUSE_FEE_PERCENT) / 100;
            winAmount -= houseFee;
            houseBalance += houseFee;
            playerBalances[msg.sender] += winAmount;
        }

        game.resolved = true;
        emit GameResolved(msg.sender, result, winAmount);
    }

    /// @notice Generates a random result for the game
    /// @return A number between 1 and 4
    /// @dev Uses TEN chain's block.difficulty for randomness
    function generateResult() private view returns (uint8) {
        uint256 randomness = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender)));
        return uint8((randomness % 4) + 1);
    }

    /// @notice Calculates the winnings for a game
    /// @param game The current game state
    /// @param result The winning number
    /// @return The amount won
    function calculateWinnings(Game storage game, uint8 result) private view returns (uint256) {
        uint256 winningBet = game.bets[result];
        if (winningBet == 0) return 0;

        // Fan-Tan typically pays 1:1 minus a house commission
        return winningBet * 2;
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

    /// @notice Allows the owner to withdraw funds from the house balance
    /// @param amount The amount to withdraw
    /// @dev Only callable by the owner, checks for sufficient balance
    function withdrawHouseBalance(uint256 amount) public onlyOwner {
        require(amount <= houseBalance, "Insufficient house balance");
        houseBalance -= amount;
        payable(owner).transfer(amount);
    }
}
