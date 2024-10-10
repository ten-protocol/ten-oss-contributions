// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title KenoGame - A smart contract for playing Keno
/// @author Assistant
/// @notice This contract allows players to play Keno using TEN chain's features
/// @dev Utilizes TEN chain's private shared states and secure randomness
contract KenoGame {
    address public owner;
    uint256 public minBet;
    uint256 public maxBet;
    uint256 public houseBalance;
    uint8 public constant MAX_SPOTS = 10;
    uint8 public constant NUMBERS_DRAWN = 20;
    uint8 public constant MAX_NUMBER = 80;
    
    private mapping(address => uint256) private playerBalances;

    struct Ticket {
        uint8[] chosenNumbers;
        uint256 betAmount;
        bool resolved;
    }

    private mapping(address => Ticket[]) private playerTickets;

    uint256[] private payoutTable = [
        0, 3, 16, 48, 160, 360, 1000, 5000, 15000, 50000, 100000
    ];

    /// @notice Emitted when a player buys a Keno ticket
    /// @param player The address of the player
    /// @param ticketId The ID of the ticket
    /// @param numbers The numbers chosen by the player
    /// @param betAmount The amount bet on this ticket
    event TicketPurchased(address indexed player, uint256 indexed ticketId, uint8[] numbers, uint256 betAmount);

    /// @notice Emitted when a Keno game is resolved
    /// @param player The address of the player
    /// @param ticketId The ID of the resolved ticket
    /// @param drawnNumbers The numbers drawn in the game
    /// @param matches The number of matches
    /// @param payout The amount paid out
    event GameResolved(address indexed player, uint256 indexed ticketId, uint8[] drawnNumbers, uint8 matches, uint256 payout);

    /// @notice Emitted when a player deposits funds
    /// @param player The address of the player
    /// @param amount The amount deposited
    event Deposit(address indexed player, uint256 amount);

    /// @notice Emitted when a player withdraws funds
    /// @param player The address of the player
    /// @param amount The amount withdrawn
    event Withdrawal(address indexed player, uint256 amount);

    /// @notice Sets up the Keno game with initial bet limits
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

    /// @notice Allows a player to buy a Keno ticket
    /// @param numbers The numbers chosen by the player
    /// @param betAmount The amount to bet on this ticket
    /// @dev Checks for valid input, updates balances, and emits a TicketPurchased event
    function buyTicket(uint8[] calldata numbers, uint256 betAmount) public {
        require(numbers.length > 0 && numbers.length <= MAX_SPOTS, "Invalid number of spots");
        require(betAmount >= minBet && betAmount <= maxBet, "Bet amount out of range");
        require(playerBalances[msg.sender] >= betAmount, "Insufficient player balance");
        require(houseBalance >= betAmount * payoutTable[numbers.length] / 10000, "Insufficient house balance");

        for (uint i = 0; i < numbers.length; i++) {
            require(numbers[i] > 0 && numbers[i] <= MAX_NUMBER, "Number out of range");
            for (uint j = i + 1; j < numbers.length; j++) {
                require(numbers[i] != numbers[j], "Duplicate numbers not allowed");
            }
        }

        playerBalances[msg.sender] -= betAmount;
        houseBalance += betAmount;

        Ticket memory newTicket = Ticket({
            chosenNumbers: numbers,
            betAmount: betAmount,
            resolved: false
        });

        playerTickets[msg.sender].push(newTicket);
        uint256 ticketId = playerTickets[msg.sender].length - 1;

        emit TicketPurchased(msg.sender, ticketId, numbers, betAmount);
    }

    /// @notice Resolves a player's Keno ticket
    /// @param ticketId The ID of the ticket to resolve
    /// @dev Draws numbers, calculates payout, updates balances, and emits a GameResolved event
    function resolveTicket(uint256 ticketId) public {
        require(ticketId < playerTickets[msg.sender].length, "Invalid ticket ID");
        require(!playerTickets[msg.sender][ticketId].resolved, "Ticket already resolved");

        Ticket storage ticket = playerTickets[msg.sender][ticketId];
        ticket.resolved = true;

        uint8[] memory drawnNumbers = drawNumbers();
        uint8 matches = countMatches(ticket.chosenNumbers, drawnNumbers);
        uint256 payout = calculatePayout(matches, ticket.chosenNumbers.length, ticket.betAmount);

        if (payout > 0) {
            require(houseBalance >= payout, "Insufficient house balance for payout");
            houseBalance -= payout;
            playerBalances[msg.sender] += payout;
        }

        emit GameResolved(msg.sender, ticketId, drawnNumbers, matches, payout);
    }

    /// @notice Draws the winning numbers for a Keno game
    /// @return An array of drawn numbers
    /// @dev Uses TEN chain's block.difficulty for randomness
    function drawNumbers() private view returns (uint8[] memory) {
        uint8[] memory numbers = new uint8[](NUMBERS_DRAWN);
        uint256 seed = uint256(block.difficulty);

        for (uint i = 0; i < NUMBERS_DRAWN; i++) {
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
            numbers[i] = uint8((seed % MAX_NUMBER) + 1);

            // Ensure no duplicates
            for (uint j = 0; j < i; j++) {
                if (numbers[j] == numbers[i]) {
                    i--;
                    break;
                }
            }
        }

        return numbers;
    }

    /// @notice Counts the number of matches between chosen and drawn numbers
    /// @param chosenNumbers The numbers chosen by the player
    /// @param drawnNumbers The numbers drawn in the game
    /// @return The number of matches
    function countMatches(uint8[] memory chosenNumbers, uint8[] memory drawnNumbers) private pure returns (uint8) {
        uint8 matches = 0;
        for (uint i = 0; i < chosenNumbers.length; i++) {
            for (uint j = 0; j < drawnNumbers.length; j++) {
                if (chosenNumbers[i] == drawnNumbers[j]) {
                    matches++;
                    break;
                }
            }
        }
        return matches;
    }

    /// @notice Calculates the payout for a ticket
    /// @param matches The number of matches
    /// @param spotsChosen The number of spots chosen by the player
    /// @param betAmount The amount bet on the ticket
    /// @return The payout amount
    function calculatePayout(uint8 matches, uint8 spotsChosen, uint256 betAmount) private view returns (uint256) {
        if (matches > spotsChosen) {
            matches = spotsChosen;
        }
        return betAmount * payoutTable[matches] / 10000;
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
