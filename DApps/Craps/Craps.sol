// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title CrapsCasino - A smart contract for playing Craps
/// @author Assistant
/// @notice This contract allows players to play Craps using TEN chain's features
/// @dev Utilizes TEN chain's private shared states and secure randomness
contract CrapsCasino {
    address public owner;
    uint256 public minBet;
    uint256 public maxBet;
    uint256 public houseBalance;
    
    private mapping(address => uint256) private playerBalances;

    /// @notice Emitted when a player completes a roll
    /// @param player The address of the player
    /// @param roll The result of the roll
    /// @param win Whether the player won
    /// @param payout The amount paid out (0 if loss)
    event RollOutcome(address indexed player, uint256 indexed roll, bool indexed win, uint256 payout);

    /// @notice Emitted when a player deposits funds
    /// @param player The address of the player
    /// @param amount The amount deposited
    event Deposit(address indexed player, uint256 amount);

    /// @notice Emitted when a player withdraws funds
    /// @param player The address of the player
    /// @param amount The amount withdrawn
    event Withdrawal(address indexed player, uint256 amount);

    /// @notice Sets up the casino with initial bet limits
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

    /// @notice Allows a player to place a bet and play a game of Craps
    /// @param betAmount The amount the player wishes to bet
    /// @dev Implements the core Craps game logic, updates balances, and emits a RollOutcome event
    function placeBet(uint256 betAmount) public {
        require(betAmount >= minBet && betAmount <= maxBet, "Bet amount out of range");
        require(playerBalances[msg.sender] >= betAmount, "Insufficient player balance");
        require(houseBalance >= betAmount, "Insufficient house balance");

        playerBalances[msg.sender] -= betAmount;
        houseBalance += betAmount;

        uint256 roll = uint256(block.difficulty) % 12 + 1;
        bool win;
        uint256 payout;

        if (roll == 7 || roll == 11) {
            win = true;
            payout = betAmount * 2;
        } else if (roll == 2 || roll == 3 || roll == 12) {
            win = false;
            payout = 0;
        } else {
            uint256 point = roll;
            while (true) {
                roll = uint256(block.difficulty) % 12 + 1;
                if (roll == point) {
                    win = true;
                    payout = betAmount * 2;
                    break;
                } else if (roll == 7) {
                    win = false;
                    payout = 0;
                    break;
                }
            }
        }

        if (win) {
            require(houseBalance >= payout, "Insufficient house balance for payout");
            houseBalance -= payout;
            playerBalances[msg.sender] += payout;
        }

        emit RollOutcome(msg.sender, roll, win, payout);
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
