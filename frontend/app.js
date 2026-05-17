const BASE_SEPOLIA_CHAIN_ID = 84532;
const SUBGRAPH_ENDPOINT_URL = "https://api.studio.thegraph.com/query/REPLACE/crypto-realm/v0.0.1";

const CONTRACT_ADDRESSES = {
    gameToken: "0x169ae7e53e9dad50edbbb07570d2cdf79c3de1b9",
    gameResources: "0x4ff5ff07e6a926c5eb6ca90adfa7acd48ff68b48",
    resourceMarketplace: "0xd15e44a413e0f299ea7e3c9cd7be4c6b5e70cf26",
    governor: "0x9c8cb7209ac3153d43d6ab217c167f200dd9bb50",
    rentalVault: "0x9a14c5fb7479c1395473ae171fc4229074b4d939"
};

const GAME_TOKEN_ABI = [
    "function balanceOf(address account) view returns (uint256)",
    "function delegate(address delegatee)",
    "function delegates(address account) view returns (address)",
    "function getVotes(address account) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)"
];

const GAME_RESOURCES_ABI = [
    "function balanceOf(address account, uint256 id) view returns (uint256)",
    "function setApprovalForAll(address operator, bool approved)",
    "function isApprovedForAll(address account, address operator) view returns (bool)"
];

const MARKETPLACE_ABI = [
    "function swapExactInputForOutput(uint256 inputResourceId, uint256 outputResourceId, uint256 inputResourceAmount, uint256 minimumOutputResourceAmount, address outputRecipient, uint256 transactionDeadline) returns (uint256)",
    "function getPoolReserves(uint256 firstResourceId, uint256 secondResourceId) view returns (uint256, uint256)"
];

const VAULT_ABI = [
    "function deposit(uint256 assets, address receiver) returns (uint256)",
    "function balanceOf(address account) view returns (uint256)"
];

let activeProvider = null;
let activeSigner = null;
let activeAccountAddress = null;

const walletConnectButton = document.getElementById("walletConnectButton");
const walletStatusMessage = document.getElementById("walletStatusMessage");
const networkWarning = document.getElementById("networkWarning");
const networkSwitchButton = document.getElementById("networkSwitchButton");
const transactionStatus = document.getElementById("transactionStatus");

walletConnectButton.addEventListener("click", connectMetaMaskWallet);
networkSwitchButton.addEventListener("click", switchToBaseSepoliaNetwork);

document.querySelectorAll(".tabButton").forEach(button => {
    button.addEventListener("click", () => switchActiveTab(button.dataset.tab));
});

document.getElementById("executeSwapButton").addEventListener("click", executeResourceSwap);
document.getElementById("delegateButton").addEventListener("click", delegateVotingPowerToSelf);
document.getElementById("vaultDepositButton").addEventListener("click", depositIntoVault);

function showTransactionMessage(messageText, isError) {
    transactionStatus.classList.remove("hidden", "bg-red-900", "bg-green-900");
    transactionStatus.classList.add(isError ? "bg-red-900" : "bg-green-900");
    transactionStatus.textContent = messageText;
    setTimeout(() => transactionStatus.classList.add("hidden"), 8000);
}

function switchActiveTab(tabName) {
    document.querySelectorAll(".tabButton").forEach(button => {
        button.classList.remove("active", "text-white");
        button.classList.add("text-gray-400");
    });
    document.querySelector(`[data-tab="${tabName}"]`).classList.add("active", "text-white");
    document.querySelectorAll(".tabContent").forEach(section => section.classList.add("hidden"));
    document.getElementById(`${tabName}Tab`).classList.remove("hidden");
}

async function connectMetaMaskWallet() {
    if (typeof window.ethereum === "undefined") {
        showTransactionMessage("MetaMask not detected. Please install MetaMask.", true);
        return;
    }
    try {
        activeProvider = new ethers.providers.Web3Provider(window.ethereum);
        await activeProvider.send("eth_requestAccounts", []);
        activeSigner = activeProvider.getSigner();
        activeAccountAddress = await activeSigner.getAddress();
        walletStatusMessage.textContent = `${activeAccountAddress.slice(0, 6)}...${activeAccountAddress.slice(-4)}`;
        walletConnectButton.textContent = "Connected";
        walletConnectButton.classList.add("bg-green-600");
        await detectNetworkAndWarn();
        await loadUserAccountData();
        await loadActiveProposalsFromSubgraph();
        await loadMarketplaceReserves();
    } catch (error) {
        showTransactionMessage(`Wallet connection failed: ${error.message}`, true);
    }
}

async function detectNetworkAndWarn() {
    const network = await activeProvider.getNetwork();
    if (network.chainId !== BASE_SEPOLIA_CHAIN_ID) {
        networkWarning.classList.remove("hidden");
    } else {
        networkWarning.classList.add("hidden");
    }
}

async function switchToBaseSepoliaNetwork() {
    try {
        await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: "0x14a34" }]
        });
        networkWarning.classList.add("hidden");
    } catch (error) {
        showTransactionMessage("Failed to switch network. Add Base Sepolia manually in MetaMask.", true);
    }
}

async function loadUserAccountData() {
    if (!activeSigner) return;
    try {
        const tokenContract = new ethers.Contract(CONTRACT_ADDRESSES.gameToken, GAME_TOKEN_ABI, activeProvider);
        const resourcesContract = new ethers.Contract(CONTRACT_ADDRESSES.gameResources, GAME_RESOURCES_ABI, activeProvider);

        const tokenBalance = await tokenContract.balanceOf(activeAccountAddress);
        const votingPower = await tokenContract.getVotes(activeAccountAddress);
        const delegateAddress = await tokenContract.delegates(activeAccountAddress);
        const woodBalance = await resourcesContract.balanceOf(activeAccountAddress, 1);
        const ironBalance = await resourcesContract.balanceOf(activeAccountAddress, 2);

        document.getElementById("realmBalanceDisplay").textContent = ethers.utils.formatEther(tokenBalance);
        document.getElementById("votingPowerDisplay").textContent = `${ethers.utils.formatEther(votingPower)} REALM`;
        document.getElementById("delegateAddressDisplay").textContent = delegateAddress;
        document.getElementById("woodBalanceDisplay").textContent = woodBalance.toString();
        document.getElementById("ironBalanceDisplay").textContent = ironBalance.toString();
    } catch (error) {
        console.error("Failed to load account data:", error);
    }
}

async function loadMarketplaceReserves() {
    if (!activeProvider) return;
    try {
        const marketplaceContract = new ethers.Contract(CONTRACT_ADDRESSES.resourceMarketplace, MARKETPLACE_ABI, activeProvider);
        const [woodReserve, ironReserve] = await marketplaceContract.getPoolReserves(1, 2);
        document.getElementById("poolReservesDisplay").textContent = `Pool: ${woodReserve} WOOD / ${ironReserve} IRON`;
    } catch (error) {
        document.getElementById("poolReservesDisplay").textContent = "Pool not initialized";
    }
}

async function loadActiveProposalsFromSubgraph() {
    const proposalsList = document.getElementById("proposalsList");
    try {
        const graphqlQuery = {
            query: `{
                proposals(first: 10, orderBy: createdTimestamp, orderDirection: desc) {
                    id
                    proposer
                    description
                    state
                    forVotes
                    againstVotes
                }
            }`
        };
        const response = await fetch(SUBGRAPH_ENDPOINT_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(graphqlQuery)
        });
        const responseData = await response.json();
        const proposalArray = responseData?.data?.proposals ?? [];

        if (proposalArray.length === 0) {
            proposalsList.innerHTML = '<p class="text-gray-400">No proposals yet.</p>';
            return;
        }

        proposalsList.innerHTML = proposalArray
    .map(
        proposal => `
    <div class="bg-gray-700 rounded p-4">
        <div class="font-semibold">${proposal.description.slice(0, 80)}</div>
        <div class="text-sm text-gray-400 mt-2 mb-3">
            State: ${proposal.state} | For: ${proposal.forVotes} | Against: ${proposal.againstVotes}
        </div>
        <div class="flex gap-2">
            <button onclick="castProposalVote('${proposal.id}', 1)" class="bg-green-600 hover:bg-green-700 px-3 py-1 rounded text-sm">Vote For</button>
            <button onclick="castProposalVote('${proposal.id}', 0)" class="bg-red-600 hover:bg-red-700 px-3 py-1 rounded text-sm">Vote Against</button>
            <button onclick="castProposalVote('${proposal.id}', 2)" class="bg-gray-600 hover:bg-gray-500 px-3 py-1 rounded text-sm">Abstain</button>
        </div>
    </div>`
    )
    .join("");
    } catch (error) {
        proposalsList.innerHTML = '<p class="text-gray-400">Subgraph not deployed yet.</p>';
    }
}

async function executeResourceSwap() {
    if (!activeSigner) {
        showTransactionMessage("Connect your wallet first.", true);
        return;
    }
    try {
        const inputId = parseInt(document.getElementById("inputResourceSelector").value);
        const outputId = parseInt(document.getElementById("outputResourceSelector").value);
        const inputAmount = document.getElementById("swapInputAmount").value;

        if (!inputAmount || inputAmount <= 0) {
            showTransactionMessage("Enter a valid swap amount.", true);
            return;
        }
        if (inputId === outputId) {
            showTransactionMessage("Cannot swap a resource for itself.", true);
            return;
        }

        const marketplaceContract = new ethers.Contract(CONTRACT_ADDRESSES.resourceMarketplace, MARKETPLACE_ABI, activeSigner);
        const deadline = Math.floor(Date.now() / 1000) + 3600;

        showTransactionMessage("Submitting swap transaction...", false);
        const transaction = await marketplaceContract.swapExactInputForOutput(
            inputId,
            outputId,
            inputAmount,
            1,
            activeAccountAddress,
            deadline
        );
        await transaction.wait();
        showTransactionMessage("Swap confirmed.", false);
        await loadUserAccountData();
        await loadMarketplaceReserves();
    } catch (error) {
        showTransactionMessage(`Swap failed: ${error.reason || error.message}`, true);
    }
}

async function delegateVotingPowerToSelf() {
    if (!activeSigner) {
        showTransactionMessage("Connect your wallet first.", true);
        return;
    }
    try {
        const tokenContract = new ethers.Contract(CONTRACT_ADDRESSES.gameToken, GAME_TOKEN_ABI, activeSigner);
        showTransactionMessage("Submitting delegation...", false);
        const transaction = await tokenContract.delegate(activeAccountAddress);
        await transaction.wait();
        showTransactionMessage("Delegation confirmed.", false);
        await loadUserAccountData();
    } catch (error) {
        showTransactionMessage(`Delegation failed: ${error.reason || error.message}`, true);
    }
}

async function depositIntoVault() {
    if (!activeSigner) {
        showTransactionMessage("Connect your wallet first.", true);
        return;
    }
    try {
        const depositAmount = document.getElementById("vaultDepositAmount").value;
        if (!depositAmount || depositAmount <= 0) {
            showTransactionMessage("Enter a valid deposit amount.", true);
            return;
        }
        const amountInWei = ethers.utils.parseEther(depositAmount);

        const tokenContract = new ethers.Contract(CONTRACT_ADDRESSES.gameToken, GAME_TOKEN_ABI, activeSigner);
        showTransactionMessage("Approving vault...", false);
        const approvalTx = await tokenContract.approve(CONTRACT_ADDRESSES.rentalVault, amountInWei);
        await approvalTx.wait();

        const vaultContract = new ethers.Contract(CONTRACT_ADDRESSES.rentalVault, VAULT_ABI, activeSigner);
        showTransactionMessage("Submitting deposit...", false);
        const depositTx = await vaultContract.deposit(amountInWei, activeAccountAddress);
        await depositTx.wait();

        const vaultShares = await vaultContract.balanceOf(activeAccountAddress);
        document.getElementById("vaultSharesDisplay").textContent = `Vault Shares: ${ethers.utils.formatEther(vaultShares)}`;
        showTransactionMessage("Deposit confirmed.", false);
    } catch (error) {
        showTransactionMessage(`Deposit failed: ${error.reason || error.message}`, true);
    }
}

async function castProposalVote(proposalId, voteOption) {
    if (!activeSigner) {
        showTransactionMessage("Connect your wallet first.", true);
        return;
    }
    try {
        const governorContract = new ethers.Contract(
            CONTRACT_ADDRESSES.governor,
            ["function castVote(uint256 proposalId, uint8 support) returns (uint256)"],
            activeSigner
        );
        showTransactionMessage("Submitting vote...", false);
        const tx = await governorContract.castVote(proposalId, voteOption);
        await tx.wait();
        showTransactionMessage("Vote cast successfully.", false);
        await loadActiveProposalsFromSubgraph();
    } catch (error) {
        showTransactionMessage(`Vote failed: ${error.reason || error.message}`, true);
    }
}

window.castProposalVote = castProposalVote;

if (typeof window.ethereum !== "undefined") {
    window.ethereum.on("chainChanged", () => window.location.reload());
    window.ethereum.on("accountsChanged", () => window.location.reload());
}