const contractABI = [
        {
            "inputs": [],
            "stateMutability": "nonpayable",
            "type": "constructor"
        },
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "player",
                    "type": "address"
                },
                {
                    "indexed": false,
                    "internalType": "uint256",
                    "name": "betAmount",
                    "type": "uint256"
                }
            ],
            "name": "BetPlaced",
            "type": "event"
        },
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "player",
                    "type": "address"
                },
                {
                    "indexed": false,
                    "internalType": "bool",
                    "name": "won",
                    "type": "bool"
                },
                {
                    "indexed": false,
                    "internalType": "uint256",
                    "name": "payout",
                    "type": "uint256"
                }
            ],
            "name": "SpinOutcome",
            "type": "event"
        },
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "player",
                    "type": "address"
                },
                {
                    "indexed": false,
                    "internalType": "uint256[3]",
                    "name": "spinResult",
                    "type": "uint256[3]"
                },
                {
                    "indexed": false,
                    "internalType": "uint256",
                    "name": "payout",
                    "type": "uint256"
                }
            ],
            "name": "SpinResult",
            "type": "event"
        },
        {
            "inputs": [],
            "name": "contractPaused",
            "outputs": [
                {
                    "internalType": "bool",
                    "name": "",
                    "type": "bool"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "fundContract",
            "outputs": [],
            "stateMutability": "payable",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "getContractBalance",
            "outputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "owner",
            "outputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "pauseContract",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "spin",
            "outputs": [],
            "stateMutability": "payable",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                }
            ],
            "name": "symbols",
            "outputs": [
                {
                    "internalType": "uint8",
                    "name": "",
                    "type": "uint8"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "unpauseContract",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "uint256",
                    "name": "amount",
                    "type": "uint256"
                }
            ],
            "name": "withdrawFunds",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }
]; 
const contractAddress = "0xDbF77F2Fc9f848d59AAD0648F68E2450AbFFDeb2";

let contract;
let userAccount;
let spinningInterval;

window.addEventListener('load', async () => {

    if (window.ethereum) {
        window.web3 = new Web3(ethereum);
        try {
            await ethereum.enable();
            initApp();
        } catch (error) {
            console.error("User denied account access");
        }
    }
    else if (window.web3) {
        window.web3 = new Web3(web3.currentProvider);
        initApp();
    }
    else {
        console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
    }
});

function initApp() {
    contract = new web3.eth.Contract(contractABI, contractAddress);
    web3.eth.getAccounts().then(accounts => {
        userAccount = accounts[0];
        console.log("Account:", userAccount);
        updateUI();
    });

    contract.events.SpinResult({
        filter: {player: userAccount},
        fromBlock: 'latest'
    })
    .on('data', event => updateReels(event.returnValues.spinResult))
    .on('error', console.error);
    
    contract.events.SpinOutcome({
        filter: {player: userAccount},
        fromBlock: 'latest'
    })
    .on('data', event => displaySpinOutcome(event.returnValues))
    .on('error', console.error);

    document.getElementById('statusValue').innerText = "SPIN NOW TO PLAY";
}

function spinReels() {
    startSpinning();

    const fixedBetAmount = "0.0443";
    contract.methods.spin().send({ from: userAccount, value: web3.utils.toWei(fixedBetAmount, 'ether') })
        .on('transactionHash', function(hash){
            console.log("Transaction Hash:", hash);
        })
        .on('confirmation', function(confirmationNumber, receipt){
            console.log("Confirmation Number:", confirmationNumber);
            stopSpinning(receipt.events.SpinResult.returnValues.spinResult);
        })
        .on('error', function(error) {
            clearInterval(spinningInterval);
            console.error(error);
        });
}

function startSpinning() {
    const symbols = ['🍎', '🍌', '🍒', '🍇', '🍋', '🍊', '🍍', '7️⃣', '🍓', '🥝'];
    const reels = document.querySelectorAll('.reel');

    spinningInterval = setInterval(() => {
        reels.forEach(reel => {
            const randomSymbol = symbols[Math.floor(Math.random() * symbols.length)];
            reel.textContent = randomSymbol;
        });
    }, 100);
}

function stopSpinning(spinResult) {
    clearInterval(spinningInterval);
    updateReels(spinResult);
}

function updateReels(spinResult) {
    const symbolMap = {0: '🍎', 1: '🍌', 2: '🍒', 3: '🍇', 4: '🍋', 5: '🍊', 6: '🍍', 7: '7️⃣', 8: '🍓', 9: '🥝'};
    for (let i = 0; i < spinResult.length; i++) {
        const reelId = `reel${i+1}`;
        const symbol = symbolMap[spinResult[i]];
        document.getElementById(reelId).textContent = symbol;
    }
}

function displaySpinOutcome(outcome) {
    let statusText = outcome.won ? `Win! Payout: ${outcome.payout} ETH` : "Lost. Spin Again!";
    document.getElementById('statusValue').innerText = statusText;
    updateUI();
}

function updateUI() {
    contract.methods.getContractBalance().call()
        .then(balance => {
            document.getElementById('balanceValue').innerText = web3.utils.fromWei(balance, 'ether');
        })
        .catch(console.error);

}

function fundContract(amount) {
    contract.methods.fundContract().send({ from: userAccount, value: web3.utils.toWei(amount, 'ether') })
        .on('transactionHash', hash => console.log("Transaction Hash:", hash))
        .on('confirmation', (confirmationNumber, receipt) => updateUI())
        .on('error', console.error);
}

function withdrawFunds(amount) {
    contract.methods.withdrawFunds(web3.utils.toWei(amount, 'ether')).send({ from: userAccount })
        .on('transactionHash', hash => console.log("Transaction Hash:", hash))
        .on('confirmation', (confirmationNumber, receipt) => updateUI())
        .on('error', console.error);
}

function togglePauseContract() {
    contract.methods.contractPaused().call().then(isPaused => {
        let method = isPaused ? contract.methods.unpauseContract() : contract.methods.pauseContract();
        method.send({ from: userAccount })
            .on('transactionHash', hash => console.log("Transaction Hash:", hash))
            .on('confirmation', (confirmationNumber, receipt) => updateUI())
            .on('error', console.error);
    });
}
document.getElementById('spinButton').addEventListener('click', spinReels);

