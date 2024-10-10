// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title KlondikeSolitaire - A smart contract for playing Klondike Solitaire
/// @author Assistant
/// @notice This contract allows players to play Klondike Solitaire using TEN chain's features
/// @dev Utilizes TEN chain's private shared states and secure randomness
contract KlondikeSolitaire {
    address public owner;
    uint256 public gameCost;
    uint256 public prizePools;
    
    private mapping(address => uint256) private playerBalances;
    private mapping(address => Game) private games;

    struct Card {
        uint8 suit; // 0: Hearts, 1: Diamonds, 2: Clubs, 3: Spades
        uint8 rank; // 1: Ace, 2-10, 11: Jack, 12: Queen, 13: King
    }

    struct Pile {
        Card[] cards;
    }

    struct Game {
        Pile[] tableau;
        Pile[] foundation;
        Pile stock;
        Pile waste;
        uint256 moves;
        uint256 startTime;
        bool completed;
    }

    event private GameStarted(address indexed player);
    event private MoveMade(address indexed player, uint256 moveType);
    event private GameCompleted(address indexed player, uint256 moves, uint256 timeTaken);

    constructor(uint256 _gameCost) {
        owner = msg.sender;
        gameCost = _gameCost;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function deposit() public payable {
        playerBalances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(playerBalances[msg.sender] >= amount, "Insufficient balance");
        playerBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function startNewGame() public {
        require(playerBalances[msg.sender] >= gameCost, "Insufficient balance to start a game");
        require(!games[msg.sender].completed, "Finish your current game first");

        playerBalances[msg.sender] -= gameCost;
        prizePools += gameCost;

        Game storage game = games[msg.sender];
        game.tableau = new Pile[](7);
        game.foundation = new Pile[](4);
        game.stock = Pile(new Card[](24));
        game.waste = Pile(new Card[](0));
        game.moves = 0;
        game.startTime = block.timestamp;
        game.completed = false;

        // Create and shuffle deck
        Card[] memory deck = createDeck();
        shuffleDeck(deck);

        // Deal cards to tableau
        uint8 cardIndex = 0;
        for (uint8 i = 0; i < 7; i++) {
            for (uint8 j = i; j < 7; j++) {
                game.tableau[j].cards.push(deck[cardIndex]);
                cardIndex++;
            }
        }

        // Remaining cards go to stock
        for (uint8 i = cardIndex; i < 52; i++) {
            game.stock.cards.push(deck[i]);
        }

        emit GameStarted(msg.sender);
    }

    function createDeck() private pure returns (Card[] memory) {
        Card[] memory deck = new Card[](52);
        uint8 index = 0;
        for (uint8 suit = 0; suit < 4; suit++) {
            for (uint8 rank = 1; rank <= 13; rank++) {
                deck[index] = Card(suit, rank);
                index++;
            }
        }
        return deck;
    }

    function shuffleDeck(Card[] memory deck) private view {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        for (uint256 i = deck.length - 1; i > 0; i--) {
            uint256 j = seed % (i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
        }
    }

    function drawFromStock() public {
        Game storage game = games[msg.sender];
        require(!game.completed, "Game is already completed");
        require(game.stock.cards.length > 0, "Stock is empty");

        Card memory drawnCard = game.stock.cards[game.stock.cards.length - 1];
        game.stock.cards.pop();
        game.waste.cards.push(drawnCard);

        game.moves++;
        emit MoveMade(msg.sender, 0); // 0 represents draw from stock
    }

    function moveToFoundation(uint8 sourceType, uint8 sourceIndex) public {
        Game storage game = games[msg.sender];
        require(!game.completed, "Game is already completed");

        Pile storage sourcePile;
        if (sourceType == 0) { // From tableau
            require(sourceIndex < 7, "Invalid tableau index");
            sourcePile = game.tableau[sourceIndex];
        } else if (sourceType == 1) { // From waste
            sourcePile = game.waste;
        } else {
            revert("Invalid source type");
        }

        require(sourcePile.cards.length > 0, "Source pile is empty");
        Card memory card = sourcePile.cards[sourcePile.cards.length - 1];

        uint8 foundationIndex = card.suit;
        Pile storage foundationPile = game.foundation[foundationIndex];

        if (foundationPile.cards.length == 0) {
            require(card.rank == 1, "Only Ace can be placed on empty foundation");
        } else {
            Card memory topFoundationCard = foundationPile.cards[foundationPile.cards.length - 1];
            require(card.rank == topFoundationCard.rank + 1, "Card must be one rank higher");
        }

        foundationPile.cards.push(card);
        sourcePile.cards.pop();

        game.moves++;
        emit MoveMade(msg.sender, 1); // 1 represents move to foundation

        checkGameCompletion(game);
    }

    function moveWithinTableau(uint8 sourceIndex, uint8 targetIndex, uint8 cardCount) public {
        Game storage game = games[msg.sender];
        require(!game.completed, "Game is already completed");
        require(sourceIndex < 7 && targetIndex < 7, "Invalid tableau index");
        require(sourceIndex != targetIndex, "Source and target must be different");

        Pile storage sourcePile = game.tableau[sourceIndex];
        Pile storage targetPile = game.tableau[targetIndex];

        require(sourcePile.cards.length >= cardCount, "Not enough cards in source pile");
        require(cardCount > 0, "Must move at least one card");

        Card memory movingCard = sourcePile.cards[sourcePile.cards.length - cardCount];

        if (targetPile.cards.length == 0) {
            require(movingCard.rank == 13, "Only King can be placed on empty tableau pile");
        } else {
            Card memory targetCard = targetPile.cards[targetPile.cards.length - 1];
            require(movingCard.rank == targetCard.rank - 1, "Card must be one rank lower");
            require((movingCard.suit + targetCard.suit) % 2 == 1, "Cards must be of different colors");
        }

        for (uint8 i = 0; i < cardCount; i++) {
            Card memory card = sourcePile.cards[sourcePile.cards.length - cardCount + i];
            targetPile.cards.push(card);
        }

        for (uint8 i = 0; i < cardCount; i++) {
            sourcePile.cards.pop();
        }

        game.moves++;
        emit MoveMade(msg.sender, 2); // 2 represents move within tableau
    }

    function checkGameCompletion(Game storage game) private {
        bool completed = true;
        for (uint8 i = 0; i < 4; i++) {
            if (game.foundation[i].cards.length != 13) {
                completed = false;
                break;
            }
        }

        if (completed) {
            game.completed = true;
            uint256 timeTaken = block.timestamp - game.startTime;
            emit GameCompleted(msg.sender, game.moves, timeTaken);

            // Award prize (example: 90% of game cost)
            uint256 prize = (gameCost * 9) / 10;
            if (prizePools >= prize) {
                prizePools -= prize;
                playerBalances[msg.sender] += prize;
            }
        }
    }

    function getGameState() public view returns (
        Card[][] memory tableau,
        Card[][] memory foundation,
        Card[] memory stock,
        Card[] memory waste,
        uint256 moves,
        bool completed
    ) {
        Game storage game = games[msg.sender];
        tableau = new Card[][](7);
        for (uint8 i = 0; i < 7; i++) {
            tableau[i] = game.tableau[i].cards;
        }
        foundation = new Card[][](4);
        for (uint8 i = 0; i < 4; i++) {
            foundation[i] = game.foundation[i].cards;
        }
        stock = game.stock.cards;
        waste = game.waste.cards;
        moves = game.moves;
        completed = game.completed;
    }

    function setGameCost(uint256 _gameCost) public onlyOwner {
        gameCost = _gameCost;
    }

    function withdrawPrizePools(uint256 amount) public onlyOwner {
        require(amount <= prizePools, "Insufficient prize pools");
        prizePools -= amount;
        payable(owner).transfer(amount);
    }
}
