# Cross-Chain Interoperability Protocol (CCIP) Rebase Token

# Introduction to Rebase Token

A rebase token capable of operating and being transferred across multiple blockchains.

## Core Concepts: Understanding the Building Blocks

Before we delve into the code, let's establish a firm understanding of the fundamental concepts that underpin this project.

- **Rebase Token:** At its heart, a rebase token is a type of cryptocurrency where the total supply adjusts algorithmically. This adjustment is distributed proportionally among all token holders. Consequently, a user's token balance changes not due to direct transfers in or out of their wallet, but because the effective quantity or "value" represented by each token unit shifts with the supply. In our specific implementation, this rebase mechanism will be tied to an interest rate, causing user balances to appear to grow over time as interest accrues.

- **Cross-Chain Functionality:** This refers to the capability of our rebase token and its associated logic to operate across different, independent blockchains. The core challenge here is enabling the token, or at least its value representation, to move from a source chain to a destination chain seamlessly.

- **Chainlink CCIP (Cross-Chain Interoperability Protocol):** CCIP is the pivotal technology enabling our token's cross-chain capabilities. It provides a secure and reliable way for smart contracts on one blockchain to send messages and transfer tokens to smart contracts on another blockchain.

- **Burn-and-Mint Mechanism (for CCIP token transfers):** To maintain a consistent total circulating supply across all integrated chains (barring changes from the rebase mechanism itself), we employ a burn-and-mint strategy. When tokens are transferred from a source chain to a destination chain:
    1.  Tokens are "burned" (irrevocably destroyed) on the source chain.
    2.  An equivalent amount of new tokens is "minted" (created) on the destination chain.

- **Foundry:** Our development environment of choice is Foundry, a powerful and fast smart contract development toolkit written in Rust. We'll use Foundry for writing, testing (including complex scenarios like fuzzing and fork testing), and deploying our Solidity smart contracts.

- **Linear Interest:** The rebase token in this project will accrue interest based on a straightforward linear model. The interest earned will be a product of the user's specific interest rate and the time elapsed since their last balance update or interaction.

- **Fork Testing:** A crucial testing methodology we'll utilize is fork testing. This involves creating a local, isolated copy (a "fork") of an actual blockchain (e.g., Sepolia testnet, Arbitrum Sepolia testnet) at a specific block height. This allows us to test our smart contracts' interactions with existing, deployed contracts and protocols in a highly realistic environment without incurring real gas costs or requiring deployment to a live testnet for every iteration.

- **Local CCIP Simulation:** To streamline development and testing of cross-chain interactions, we will use tools like Chainlink Local's `CCIPLocalSimulatorFork`. This enables us to simulate CCIP message passing and token transfers entirely locally, which is invaluable for debugging and verifying logic before engaging with public testnets.

## Learning Objectives for This Section

- The fundamentals and practical application of Chainlink CCIP.
- How to enable an existing token for CCIP compatibility.
- Techniques for creating _custom_ tokens specifically designed for CCIP, going beyond standard ERC20s.
- The design and implementation of a rebase token.
- Advanced Solidity and Foundry concepts, including:
    - Effective use of the `super` keyword for inheriting and extending contract functionality.
    - Sophisticated testing strategies.
    - Understanding and mitigating issues related to "token dust" (minute, economically insignificant token balances).
    - Handling precision and truncation challenges inherent in financial calculations, especially critical for rebase mechanisms.
    - Practical application of fork testing.
    - The use of nested structs for organizing complex data.
- The mechanics of bridging tokens between different blockchains.
- The intricacies of cross-chain transfers.

## Smart Contract Architecture and Implementation Details

Let's explore the key smart contracts that constitute our cross-chain rebase token system.

### `RebaseToken.sol`: The Heart of Our Interest-Bearing Token

This contract defines the core logic for our rebase token.

- **Purpose:** To implement an ERC20-like token whose balances effectively increase over time due to an accrued interest mechanism.
- **Key Functions/Logic:**
    - `constructor()`: Initializes the token with standard parameters like name (e.g., "RebaseToken") and symbol (e.g., "RBT").
    - `balanceOf(address user) public view override returns (uint256)`: This function is a cornerstone of the rebase mechanism and behaves distinctively. Instead of merely returning a stored balance from a mapping, it _dynamically calculates_ the user's current effective balance. It achieves this by taking the user's `currentPrincipalBalance` (which is the underlying ERC20-like balance, accessed via `super.balanceOf(user)`) and adding the `_calculateUserAccumulatedInterestSinceLastUpdate(user)`. The result is then adjusted by a `PRECISION_FACTOR` to manage decimal precision.
        ```solidity
        // Conceptual Solidity representation
        // function balanceOf(address user) public view override returns (uint256) {
        //     uint256 currentPrincipalBalance = super.balanceOf(user); // Underlying stored balance
        //     if (currentPrincipalBalance == 0) return 0;
        //     // 'shares' represents the newly accrued interest for the user since their last update
        //     uint256 accruedInterest = _calculateUserAccumulatedInterestSinceLastUpdate(user);
        //     return (currentPrincipalBalance + accruedInterest) / PRECISION_FACTOR; // Or multiplied, depending on precision handling strategy
        // }
        ```
    - **Modified Mint and Burn Functions:** The standard `_mint` and `_burn` functions (or their equivalents) will be augmented. Before any transfer, minting, or burning operation that affects a user's balance, a function like `_mintAccruedInterest(address user)` will be called. This function crystallizes any pending accrued interest into the user's principal balance, ensuring that all subsequent operations are based on their most up-to-date holdings.
    - **Interest Calculation Logic:**
        - `_calculateUserAccumulatedInterestSinceLastUpdate(address user)`: This internal function determines the amount of interest a user has earned since their last balance-modifying transaction or explicit interest update.
        - `_calculateLinearInterest(uint256 interestRate, uint256 timeDifference)`: This function implements the linear interest model: `linearInterest = (interestRate * timeDifference) / PRECISION_FACTOR`. It uses `s_userInterestRate[user]` (a mapping storing each user's specific interest rate) and the `timeDifference` since the last interest calculation point.

### `RebaseTokenPool.sol`: Enabling Cross-Chain Transfers with CCIP

This contract is responsible for managing the cross-chain movement of our rebase token using Chainlink CCIP. It will likely inherit from or extensively utilize Chainlink's `Pool.sol` contract or similar CCIP-specific base contracts.

- **Purpose:** To facilitate the burn-and-mint mechanism for transferring the rebase token between different blockchains via CCIP.
- **Key Functions/Logic:**
    - It implements the burn-and-mint pattern:
        - `lockOrBurn(...)` (or a similarly named function): When tokens are sent from the source chain, this function is called. It burns the specified amount of rebase tokens on the source chain and then constructs and dispatches a CCIP message to the destination chain, instructing it to mint an equivalent amount.
        - `releaseOrMint(...)` (or a similarly named function): On the destination chain, this function is triggered upon receiving a valid CCIP message from the source chain's pool. It then mints the appropriate amount of rebase tokens to the recipient.
    - It will also handle the encoding of necessary data, such as the user's current interest rate, to be sent along with the CCIP message. This ensures that user-specific parameters are correctly propagated across chains.

### `Vault.sol`: Interacting with the Rebase Token

The `Vault.sol` contract serves as an interface for users to acquire or redeem rebase tokens using a base asset (e.g., ETH).

- **Purpose:** To allow users to deposit a base asset (like ETH) and receive rebase tokens in return, and conversely, to redeem their rebase tokens for the underlying base asset.
- **Key Functions/Logic:**
    - `deposit() public payable`: Users send ETH to this function. The contract then mints an appropriate amount of rebase tokens to the user, calculated based on the current exchange rate (which might implicitly consider the token's accrued interest characteristics).
    - `redeem(uint256 amount)`: Users call this function, specifying the amount of rebase tokens they wish to redeem. The contract burns these rebase tokens from the user's balance and sends the corresponding amount of the base asset (ETH) back to the user.
    - `receive() external payable {}`: This special function allows the contract to receive ETH directly (e.g., through simple transfers), which is typically routed to the deposit logic.

## Development Workflow: Scripts and Testing Strategies

Foundry's scripting and testing capabilities are integral to our development process.

### Foundry Scripts (`script/` directory)

This directory houses Solidity scripts (`.s.sol` files) for automating deployment, configuration, and on-chain interactions.

- `Deployer.s.sol`: This script handles the deployment of the `RebaseToken`, `RebaseTokenPool`, and `Vault` contracts to the target blockchain.
- `ConfigurePool.s.sol`: After deployment, this script is used to configure the CCIP settings on the `RebaseTokenPool` contracts on each chain. This includes setting parameters like supported remote chains (using their chain selectors), addresses of token contracts on other chains, and rate limits for CCIP transfers.
- `BridgeTokens.s.sol`: This script provides a convenient way to initiate a cross-chain token transfer, automating the calls to the `RebaseTokenPool` for locking/burning and CCIP message dispatch.
- `Interactions.s.sol`: (Implied) This script would likely contain functions for other general interactions with the deployed contracts, such as depositing into the vault or checking balances.

### Foundry Tests (`test/` directory)

Rigorous testing is paramount, especially for financial applications involving cross-chain interactions.

- **`RebaseToken.t.sol`**:
    - **Purpose:** Contains unit and fuzz tests specifically for the `RebaseToken.sol` contract.
    - **Key Test Feature:** Employs `assertApproxEqAbs(value1, value2, delta)` for assertions. Due to the nature of interest calculations over time and potential floating-point arithmetic nuances (even when emulated with fixed-point in Solidity), rebase calculations can lead to very minor precision differences. Using `assertApproxEqAbs` allows us to verify that calculated values are within an acceptable tolerance (delta) of expected values, rather than insisting on exact equality (`assertEq`) which might lead to spurious test failures.

- **`CrossChain.t.sol`**:
    - **Purpose:** Contains fork tests designed to validate the end-to-end cross-chain functionality.
    - **Key Test Features:**
        - Utilizes `vm.createFork("rpc_url")` to create local forks of testnets like Sepolia and Arbitrum Sepolia. This allows tests to run against a snapshot of the real chain state.
        - Integrates `CCIPLocalSimulatorFork` from Chainlink Local. This powerful tool enables the simulation of CCIP message routing and execution between these local forks, effectively creating a local, two-chain (or multi-chain) test environment.
        - The test setup involves initializing two (or more) forked environments to represent the source and destination chains for the cross-chain operations.

## Automating Deployment and Cross-Chain Operations: The `bridgeToZkSync.sh` Script

To streamline the entire process from deployment to a live cross-chain transfer, a bash script like `bridgeToZkSync.sh` is invaluable.

- **Purpose:** This script automates a complex sequence of operations involving contract deployments, configurations, and interactions across multiple chains (e.g., Sepolia and zkSync Sepolia).
- **Steps it typically performs:**
    1.  Sets necessary permissions for the `RebaseTokenPool` contract, often involving CCIP-specific roles.
    2.  Assigns CCIP roles and configures permissions for inter-chain communication.
    3.  Deploys the core contracts (`RebaseToken`, `RebaseTokenPool`, `Vault`) to a source chain (e.g., Sepolia) using `script/Deployer.s.sol`.
    4.  Parses the deployment output to extract the addresses of the newly deployed contracts.
    5.  Deploys the `Vault` (and potentially `RebaseToken` and `RebaseTokenPool` if not already deployed as part of a unified script) on the destination chain (e.g., zkSync Sepolia).
    6.  Configures the `RebaseTokenPool` on the source chain (Sepolia) using `script/ConfigurePool.s.sol`, linking it to the destination chain by setting remote chain selectors, token addresses on the destination chain, and CCIP rate limits.
    7.  Simulates user interaction by depositing funds (e.g., ETH) into the `Vault` on Sepolia, thereby minting rebase tokens.
    8.  Includes a pause or wait period to allow some interest to accrue on the rebase tokens.
    9.  Configures the `RebaseTokenPool` on the destination chain (zkSync Sepolia), establishing the reciprocal CCIP linkage.
    10. Initiates a cross-chain transfer of the rebase tokens from Sepolia to zkSync Sepolia using `script/BridgeTokens.s.sol`.
    11. Performs balance checks on both chains before and after the bridge operation to verify the successful transfer and correct accounting.

## Key Takeaways and Best Practices

Several important principles and practices emerge from this advanced development exercise:

- **Precision is Paramount:** When working with rebase tokens and time-based interest calculations, meticulous attention to precision is crucial. Use fixed-point arithmetic carefully in Solidity and employ approximate equality assertions like `assertApproxEqAbs` in your tests to account for minor, unavoidable discrepancies.
- **Local Simulation is Vital:** The ability to simulate complex cross-chain interactions locally, using tools like `CCIPLocalSimulatorFork`, dramatically accelerates the development and debugging cycle. It allows for rapid iteration before deploying to live testnets.
- **Automation through Scripting:** For multi-step, multi-chain deployment and interaction workflows, bash scripting (or other scripting languages) provides powerful automation, reducing manual errors and improving repeatability.
- **Leverage `super` for Extensibility:** The `super` keyword in Solidity is essential when inheriting from base contracts (like standard ERC20 implementations or CCIP base contracts). It allows you to extend or modify parent contract functionality while still being able to invoke the original parent implementation where needed.
- **Handle Token Dust:** Be mindful of "token dust"—very small, often economically insignificant, token balances that can arise from precision issues or certain transaction patterns. While not explicitly detailed in the summary for this token, it's a general consideration in token design.
- **Address Truncation:** Understand how integer division in Solidity can lead to truncation and ensure your calculations, especially those involving rates and time, are designed to minimize adverse effects.

## Example Use Case: Putting It All Together

By the conclusion of this section's practical application, a developer would be able to execute the following end-to-end flow:

1.  **Deployment:** Deploy the `RebaseToken`, `RebaseTokenPool`, and `Vault` smart contracts onto the Sepolia testnet.
2.  **Cross-Chain Deployment:** Deploy the corresponding smart contracts (or at least the `RebaseTokenPool` and potentially a `RebaseToken` representation) onto a second testnet, such as zkSync Sepolia.
3.  **CCIP Configuration:** Configure Chainlink CCIP lanes between the deployed `RebaseTokenPool` contracts on Sepolia and zkSync Sepolia, enabling them to communicate and transfer tokens.
4.  **Acquire Rebase Tokens:** Interact with the `Vault` contract on Sepolia by depositing ETH, thereby receiving an initial balance of rebase tokens.
5.  **Interest Accrual:** Observe as the rebase token balance in the Sepolia wallet increases over time, reflecting the accrued interest as per the token's rebase mechanism.
6.  **Cross-Chain Transfer:** Execute the `BridgeTokens.s.sol` Foundry script (or the overarching `bridgeToZkSync.sh` bash script). This script will:
    - Instruct the `RebaseTokenPool` on Sepolia to burn a specified amount of the user's rebase tokens.
    - Initiate a CCIP message to the `RebaseTokenPool` on zkSync Sepolia.
    - Upon successful CCIP message relay, the `RebaseTokenPool` on zkSync Sepolia will mint an equivalent amount of rebase tokens to the user's address on that chain.
7.  **Verification:** The user can then verify their new rebase token balance on zkSync Sepolia and the correspondingly reduced (or zeroed, if all tokens were bridged) balance on Sepolia.

This comprehensive example demonstrates the power of combining custom token logic with robust cross-chain interoperability solutions to create sophisticated and flexible DeFi applications.

# What Is a Rebase Token

## Introduction: The Mystery of Changing Token Balances

Have you ever checked your cryptocurrency wallet and noticed your token balance has changed, even though you haven't executed any buy or sell orders? This intriguing phenomenon isn't a glitch; it's often the characteristic behavior of a special type of cryptocurrency known as a "rebase token." This lesson will demystify rebase tokens, explaining how and why they can alter your holdings automatically.

## What Are Rebase Tokens? Defining Elastic Supply in Crypto

A rebase token is a cryptocurrency engineered with an elastic supply. This means its **total circulating supply algorithmically adjusts** rather than remaining fixed. These adjustments, commonly referred to as "rebases," are triggered by specific protocols or algorithms. The primary purpose of a rebase mechanism is to either reflect changes in the token's underlying value or to distribute accrued rewards, such as interest, directly to token holders by modifying their balances.

## Key Differentiators: Rebase Tokens vs. Standard Cryptocurrencies

The fundamental distinction between rebase tokens and conventional cryptocurrencies lies in how they respond to changes in value or accumulated rewards.

- **Standard Tokens:** With a standard cryptocurrency, the total supply generally remains constant (barring events like burns or new minting governed by different rules). When demand increases or the protocol accrues value, the _price per token_ typically adjusts upwards. Conversely, negative factors tend to decrease the price.
- **Rebase Tokens:** In contrast, rebase tokens are designed so that their _total supply_ expands or contracts. When a protocol aims to distribute rewards or adjust to value changes, instead of the token's market price fluctuating significantly, the quantity of tokens each holder possesses changes. The price per token aims to remain more stable or target a specific peg, while the supply absorbs the value changes.

This "elastic supply" mechanism means your individual token balance can increase or decrease without any direct action on your part.

## Exploring the Types of Rebase Tokens

Rebase tokens can be broadly categorized based on their primary objective:

1.  **Rewards Rebase Tokens:** These tokens are commonly found in decentralized finance (DeFi) protocols, particularly in lending and borrowing platforms. Their supply increases to distribute earnings, such as interest, directly to token holders. As the protocol generates revenue, it's reflected as an increase in the number of tokens held by users.
2.  **Value Stability Rebase Tokens:** This category includes tokens designed to maintain a stable value relative to an underlying asset or currency (e.g., USD). Often associated with algorithmic stablecoins, these tokens adjust their supply to help maintain their price peg. If the token's market price deviates from its target, a rebase can occur: increasing supply if the price is too high (to bring it down) or decreasing supply if the price is too low (to push it up).

## How Rebase Mechanisms Work: A Practical Example of a Positive Rebase

To understand the impact of a rebase, let's consider a hypothetical scenario involving a positive rebase, typically seen with rewards distribution:

Imagine you hold 1,000 tokens of a specific rebase cryptocurrency. The protocol associated with this token decides to distribute 10% interest to all holders via a positive rebase.

- **Before Rebase:** Your balance is 1,000 tokens.
- **Rebase Event:** The protocol executes a +10% rebase.
- **After Rebase:** Your wallet balance automatically updates to 1,100 tokens (1,000 tokens + 10% of 1,000 tokens).

Crucially, while your token quantity increases, your **proportional ownership of the total token supply remains unchanged.** This is because every token holder experiences the same percentage increase in their balance. If the total supply increased by 10%, and your holdings also increased by 10%, your share of the network is preserved. The same logic applies in reverse for negative rebases, where everyone's balance would decrease proportionally.

## Real-World Application: Aave's aTokens Explained

One of the most prominent examples of rewards rebase tokens in action is Aave's aTokens. Aave is a leading decentralized lending and borrowing protocol.

Here’s how aTokens function within the Aave ecosystem:

1.  **Depositing Assets:** When you deposit an asset like USDC or DAI into the Aave protocol, you are essentially lending your cryptocurrency to the platform's liquidity pool.
2.  **Receiving aTokens:** In return for your deposit, Aave issues you a corresponding amount of aTokens (e.g., aUSDC for USDC deposits, aDAI for DAI deposits). These aTokens represent your claim on the underlying deposited assets plus any accrued interest.
3.  **Accruing Interest via Rebase:** The aTokens you hold are rebase tokens. As your deposited assets generate interest from borrowers within the Aave protocol, your balance of aTokens automatically increases over time. This increase directly reflects the interest earned.
4.  **Redemption:** You can redeem your aTokens at any time to withdraw your original principal deposit plus the accumulated interest, which is represented by the increased quantity of your aTokens.

This mechanism provides a seamless way for users to earn passive income, with their interest earnings visibly accumulating as an increase in their aToken balance.

## Deep Dive: The Smart Contract Behind Aave's aTokens

The magic of rebase tokens like Aave's aTokens is executed through smart contracts. To understand how your balance dynamically updates, we can look at the `AToken.sol` smart contract, publicly available on GitHub (e.g., at `github.com/aave-protocol/contracts/blob/master/contracts/tokenization/AToken.sol`).

A key function in ERC-20 token contracts is `balanceOf(address _user)`, which returns the token balance of a specified address. For standard tokens, this function typically retrieves a stored value. However, for rebase tokens like aTokens, the `balanceOf` function is more dynamic. It doesn't just fetch a static number; it calculates the user's current balance, including any accrued interest, at the moment the function is called.

Within Aave's `AToken.sol` contract, the `balanceOf` function incorporates logic to compute the user's principal balance plus the interest earned up to that point. It often involves internal functions like `calculateSimulatedBalanceInternal` (or similar, depending on the contract version and specific implementation details), which is crucial for dynamically calculating the balance including interest. This function effectively determines the "scaled balance" by factoring in the accumulated interest.

For instance, a simplified conceptual view of the logic within such a `balanceOf` function might be:

```solidity
function balanceOf(address _user) public view returns (uint256) {
    // ... other checks and retrieval of current principal balance ...
    uint256 currentPrincipalBalance = getUserPrincipalBalance(_user);
    uint256 accruedInterest = calculateAccruedInterest(_user, currentPrincipalBalance);

    // The returned balance reflects the principal plus the rebased interest
    return currentPrincipalBalance + accruedInterest;
}
```

_(Note: The actual Aave `AToken.sol` contract code is more complex, handling aspects like interest redirection and using scaled balances. The snippet above is a conceptual simplification to illustrate the dynamic calculation of interest within the `balanceOf` call, highlighting that functions like `calculateSimulatedBalanceInternal` play a key role in this process.)_

This dynamic calculation ensures that your aToken balance accurately reflects your underlying deposit and the interest it has generated, changing in real-time as interest accrues.

## Aave's aTokens in Action: A Numerical Illustration

Let's solidify the concept of Aave's aTokens with a simple numerical example:

- **Scenario:** You deposit 1,000 USDC into the Aave protocol.
- **Action:** In return, you receive 1,000 aUSDC (assuming a 1:1 initial minting ratio).
- **Interest Rate:** Let's assume the variable annual percentage rate (APR) for USDC lending averages out to 5% over one year.

- **Result After One Year:** Due to the rebase mechanism of aUSDC, your balance will have grown to reflect the earned interest. After one year at a 5% APR, your aUSDC balance would automatically increase to approximately 1,050 aUSDC.

When you decide to withdraw, you would redeem your 1,050 aUSDC and receive back 1,050 USDC (your original 1,000 USDC deposit plus 50 USDC in interest). The rebase token seamlessly handled the interest accrual by increasing your token quantity.

## The Significance of Rebase Tokens in DeFi and Beyond

Rebase tokens, with their elastic supply mechanism, play a crucial role in various corners of the Web3 ecosystem, particularly within Decentralized Finance (DeFi). Understanding how they function is vital for anyone interacting with:

- **Lending and Borrowing Protocols:** As seen with Aave's aTokens, they provide an intuitive way to represent and distribute interest earnings.
- **Algorithmic Stablecoins:** Some stablecoins use rebasing to help maintain their price peg to a target asset.
- **Yield Farming and Staking:** Certain protocols might use rebase mechanics to distribute rewards.

By adjusting supply rather than price to reflect value changes or distribute rewards, rebase tokens offer a unique approach to tokenomics. Recognizing when you're holding a rebase token can prevent confusion and help you better understand the dynamics of your cryptocurrency portfolio. As the blockchain space continues to innovate, rebase mechanisms are likely to find further applications, making them an important concept for any informed Web3 participant.

# Rebase Token Code Structure

Our ultimate objective is to construct a sophisticated cross-chain rebase token leveraging Chainlink's Cross-Chain Interoperability Protocol (CCIP). However, given the inherent complexities of both rebase mechanics and cross-chain communication, we'll adopt a phased approach. Our first critical step is to build and thoroughly understand a standard, single-chain rebase token. This foundational knowledge will be indispensable before we introduce the additional layer of CCIP functionality. Rebase tokens themselves are non-trivial, so a methodical, step-by-step process is key to success.

## Preparing Your Foundry Development Environment

To begin, we need to set up our development environment using Foundry, a powerful and fast toolkit for Ethereum application development.

1.  **Create Project Directory:**
    Open your terminal and create a new directory for our project. You can name it descriptively; for this lesson, we'll use `ccip-rebase-token`.

    ```bash
    mkdir ccip-rebase-token
    cd ccip-rebase-token
    ```

2.  **Initialize Foundry Project:**
    Within your new project directory, initialize a Foundry project.

    ```bash
    forge init
    ```

    This command scaffolds a standard Foundry project structure, creating `src` (for contracts), `script` (for deployment/interaction scripts), `test` (for tests), and `lib` (for dependencies) folders. It also sets up configuration files and automatically installs `forge-std`, Foundry's standard library.

3.  **Open in VS Code:**
    Open the newly created project in your preferred code editor, such as Visual Studio Code.

    ```bash
    code .
    ```

4.  **Clean Up Default Files:**
    To start with a clean slate, we'll remove the default example files generated by `forge init`. Delete the following files:
    - `src/Counter.sol`
    - `script/Counter.s.sol`
    - `test/Counter.t.sol`
      Additionally, clear the contents of the `README.md` file.

## Core Design of the Single-Chain Rebase Token

With our environment ready, let's outline the core design principles and functionality of our rebase token, as we would typically document in a `README.md` file.

### Protocol Overview

The fundamental idea is to create a system where users can deposit an underlying asset (for example, ETH or a stablecoin like WETH) into a central smart contract, which we'll refer to as the `Vault`. In exchange for their deposit, users receive `rebase tokens`. These `rebase tokens` are special; they represent the user's proportional share of the total underlying assets held within the `Vault`, including any interest or rewards that accrue over time.

### Understanding Rebase Token Mechanics

The defining characteristic of a rebase token is how its supply adjusts, directly impacting a holder's balance.

- **Dynamic Balances:** The `balanceOf(address user)` function, a standard ERC20 view function, will be designed to return a _dynamic_ value. This means that when a user queries their balance, it will appear to increase over time, reflecting their share of accrued interest or rewards. In our specific implementation, this increase will be calculated _linearly_ with time.

- **`balanceOf` is a View Function (Gas Efficiency):** It's crucial to understand that the `balanceOf` function _shows_ the user's current theoretical balance, including dynamically calculated interest. However, calling `balanceOf` itself does _not_ execute a state-changing transaction on the blockchain. It doesn't mint new tokens with every call, as that would incur gas costs for simply viewing a balance. This design is critical for gas efficiency.

- **State Update on Interaction:** The actual _minting_ of the accrued interest (i.e., updating the user's on-chain token amount) will occur strategically _before_ a user performs any state-changing action with their tokens. These actions include:
    - Depositing more underlying assets (minting more rebase tokens).
    - Withdrawing/redeeming their underlying assets (burning rebase tokens).
    - Transferring their rebase tokens to another address.
    - (In the future) Bridging their tokens to another chain.

    The mechanism works as follows: When a user initiates one of these actions, the contract will first check the time elapsed since their last interaction. It then calculates the interest accrued to that user during this period, based on their specific interest rate. These newly calculated interest tokens are then _minted_ to the user's recorded balance _on-chain_. Only _after_ this balance update does the contract proceed to execute the user's original requested action (e.g., transfer, burn) with their now up-to-date balance.

### The Interest Rate Model: Rewarding Early Adopters

Our interest rate mechanism is designed to incentivize early participation in the protocol.

- **Global Interest Rate:** The protocol will feature a `global interest rate`. This rate, potentially managed by an `owner` or a governance mechanism, determines the base rate at which interest accrues for the entire protocol at any given moment.

- **Decreasing Global Rate (Key Feature):** A critical design choice is that this `global interest rate` can _only decrease_ over time. It cannot be increased by the owner once set or lowered.

- **User-Specific Interest Rate Snapshot:** When a user makes their _first_ deposit into the `Vault`, the `Rebase Token` contract takes a _snapshot_ of the _current_ `global interest rate`. This snapshot becomes the user's _individual, fixed interest rate_ for that specific deposit.

- **Incentivizing Early Adopters:** This design directly rewards early users. Because the global interest rate can only decrease, users who deposit earlier effectively lock in a higher interest rate for their initial capital compared to users who deposit later, when the global rate might have been reduced.

- **Handling Subsequent Deposits:** If an existing user makes _additional_ deposits at a later time, those new deposits would likely accrue interest based on the (potentially lower) `global interest rate` prevailing _at the time of the new deposit_. The exact mechanics for handling multiple deposits from the same user and their associated rates will be detailed during contract implementation.

- **Conceptual Source of Yield:** While the underlying assets in the `Vault` could theoretically be deployed in various DeFi strategies (e.g., staking, lending, liquidity provision) to generate yield, for this initial version, the "interest" is primarily a function of the rebase mechanism itself, designed to increase token adoption by directly rewarding token holders with more tokens.

## Illustrating the Interest Rate Flow

Let's visualize how this interest rate mechanism plays out for different users at different times:

1.  **Initial User Deposit (User 1):**
    - `User 1` deposits ETH into the `Vault Contract`.
    - The `Vault Contract` communicates with the `Rebase Token` contract.
    - Let's assume the `Rebase Token` contract currently has its `globalInterestRate` set to 0.05 (or 5%).
    - The `Rebase Token` contract records that `User 1's Interest Rate` is 0.05. This rate is now locked in for User 1's initial deposit.
    - The `Vault Contract` mints and sends the corresponding amount of `rebase tokens` to `User 1`.

2.  **Owner Adjusts Global Rate:**
    - Sometime later, an `Owner` (or governance) interacts with the `Rebase Token` contract.
    - The `Owner` decides to _decrease_ the `globalInterestRate`, for example, from 0.05 down to 0.04 (4%).

3.  **New User Deposit (User 2):**
    - Now, `User 2` decides to deposit ETH into the `Vault Contract`.
    - The `Vault Contract` again communicates with the `Rebase Token` contract.
    - The `Rebase Token` contract's `globalInterestRate` is now 0.04.
    - The `Rebase Token` contract records that `User 2's Interest Rate` is 0.04. This is User 2's locked-in rate.
    - The `Vault Contract` mints and sends `rebase tokens` to `User 2`.

4.  **Outcome and Further Rate Adjustments:**
    - As time progresses, `User 1` will continue to accrue interest based on their higher, locked-in rate of 0.05.
    - `User 2`, having deposited later, will accrue interest based on their lower, locked-in rate of 0.04. This clearly demonstrates the early adopter incentive.
    - If the `Owner` were to decrease the `globalInterestRate` again, say to 0.02, it would not affect the already locked-in rates for `User 1` (still 0.05) or `User 2` (still 0.04). Any new depositors after this change would receive the 0.02 rate.

This step-by-step approach—starting with a single-chain rebase token and carefully considering its mechanics—will provide a solid foundation before we embark on the more complex journey of adding cross-chain capabilities. The dynamic balance calculation versus actual state updates might seem intricate at first, but it will become clearer as we translate these concepts into smart contract code.

# Writing the rebase token

## Initial Project Setup and Contract Definition

Let's begin by setting up our Solidity file and defining the basic contract structure.

First, create a new Solidity file named `RebaseToken.sol` within your project's `src` directory.

Every Solidity file should start with an SPDX license identifier and a pragma directive specifying the compiler version. For this project, we'll use the MIT license and Solidity version `0.8.24` or compatible patch versions.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
```

The `SPDX-License-Identifier` is standard practice for open-source contracts, clearly stating how others can use your code.

The `pragma solidity ^0.8.24;` line instructs the compiler on which Solidity version the code is written for, ensuring compatibility and access to specific language features. The caret (`^`) allows for compiler versions from `0.8.24` up to, but not including, `0.9.0`.

Now, let's define the basic shell for our contract:

```solidity
contract RebaseToken {

}
```

## Integrating OpenZeppelin's ERC20 Standard

To avoid reinventing the wheel and to leverage well-audited, secure code, we'll build our `RebaseToken` on top of OpenZeppelin's standard ERC20 implementation. This is a common best practice in smart contract development.

We'll use Foundry to manage our dependencies. To install OpenZeppelin Contracts, navigate to their GitHub repository (e.g., `https://github.com/OpenZeppelin/openzeppelin-contracts`) to find the latest stable version. For this lesson, we'll use version `v5.1.0`. It's crucial to pin dependency versions to ensure reproducible builds.

Run the following Foundry command in your terminal:

```bash
forge install openzeppelin/openzeppelin-contracts@v5.1.0
```

The `forge install` command adds the OpenZeppelin library as a submodule to your project. The `@v5.1.0` part pins it to that specific version.

The `--no-commit` flag is used here to prevent Foundry from automatically committing the submodule changes, which is useful if you have uncommitted changes in your local repository.

Next, import the `ERC20` contract into your `RebaseToken.sol` file. We'll use a named import, which is preferred as it only brings the necessary components into your contract's scope:

```solidity
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
```

To enable the Solidity compiler to resolve the `@openzeppelin/` import path, you need to add a remapping to your `foundry.toml` file. This makes your import paths cleaner and more portable.

```toml
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/"
]
```

After adding the remapping, you can run `forge build` to confirm that the setup is correct and the compiler can find the OpenZeppelin contracts.

## Structuring the Basic RebaseToken

With OpenZeppelin integrated, we can now define the `RebaseToken` contract to inherit from `ERC20`.

Modify your contract definition as follows:

```solidity
contract RebaseToken is ERC20 {
    // ...
}
```

Next, we'll add a constructor. The constructor for `RebaseToken` must call the parent `ERC20` constructor, providing the token's name and symbol.

```solidity
constructor() ERC20("Rebase Token", "RBT") {
    // We will handle initial minting later, so this remains empty for now.
}
```

## Documenting with NatSpec Comments

Clear documentation is vital for smart contract development. Solidity supports the Ethereum Natural Language Specification Format (NatSpec) for this purpose. Good NatSpec comments make your contract easier to understand, integrate with, and can also help AI code assistants provide better suggestions.

Let's add NatSpec comments to our `RebaseToken` contract:

```solidity
/**
 * @title RebaseToken
 * @author Your Name/Alias
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20 {
    // ... constructor and other code ...
}
```

## Implementing Interest Rate Logic

Now, let's introduce the core mechanics for handling interest rates.

**State Variables for Interest Calculation:**

We need several state variables to manage interest:

1.  `PRECISION_FACTOR`: A constant to handle decimal precision. Solidity doesn't have native floating-point numbers, so we use integers and scale them. `1e18` (1 followed by 18 zeros) is commonly used to represent 1 or 100% with 18 decimal places of precision.

    ```solidity
    uint256 private constant PRECISION_FACTOR = 1e18;
    ```

2.  `s_interestRate`: This will store the global interest rate per second for the contract. The `s_` prefix is a common convention for storage variables. Let's initialize it to `5e10`. If `1e18` represents 100%, then `5e10` represents a rate of `(5e10 / 1e18) = 0.00000005` or `0.000005%` per second.

    ```solidity
    uint256 private s_interestRate = 5e10;
    ```

3.  `s_userInterestRate`: A mapping to store the specific interest rate "locked in" for each user when they first interact (e.g., mint tokens).

    ```solidity
    mapping(address => uint256) private s_userInterestRate;
    ```

4.  `s_userLastUpdatedTimestamp`: A mapping to store the timestamp of the last time each user's balance effectively accrued interest or was updated.

    ```solidity
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    ```

### Custom Error and Event for Interest Rate Changes:

To provide better error handling and enable off-chain monitoring, we'll define a custom error and an event related to interest rate changes.

```solidity
error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);
event InterestRateSet(uint256 newInterestRate);
```

### `setInterestRate` Function:

This function will allow an authorized party (e.g., the contract owner) to set the global `s_interestRate`. A key requirement is that this rate can only ever decrease, rewarding early adopters.

```solidity
/**
 * @notice Set the global interest rate for the contract.
 * @param _newInterestRate The new interest rate to set (scaled by PRECISION_FACTOR basis points per second).
 * @dev The interest rate can only decrease. Access control (e.g., onlyOwner) should be added.
 */
function setInterestRate(uint256 _newInterestRate) external { // TODO: Add access control
    if (_newInterestRate > s_interestRate) {
        revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
    }
    s_interestRate = _newInterestRate;
    emit InterestRateSet(_newInterestRate);
}
```

_Note:_ The condition `_newInterestRate > s_interestRate` ensures that the function reverts if an attempt is made to set a new rate higher than the current one, enforcing the "can only decrease" rule.

### `getUserInterestRate` Getter Function:

We'll provide a public view function to allow anyone to query a user's locked-in interest rate.

```solidity
/**
 * @notice Gets the locked-in interest rate for a specific user.
 * @param _user The address of the user.
 * @return The user's specific interest rate.
 */
function getUserInterestRate(address _user) external view returns (uint256) {
    return s_userInterestRate[_user];
}
```

## Minting Tokens and Accruing Interest

The `mint` function is a critical part of our rebase token. It will be called when a user performs an action that results in new tokens being created for them (e.g., depositing assets into an associated vault).

### `mint` Function Logic:

When `mint` is called for a user:

1.  Any interest that has accrued for this user since their last interaction must be calculated and minted to them. This is handled by an internal function `_mintAccruedInterest`.
2.  The user's specific interest rate (`s_userInterestRate[_to]`) is set to the current global `s_interestRate`. This "locks in" the prevailing rate for their newly minted tokens.
3.  The actual principal amount of tokens is minted using the standard ERC20 `_mint` function.

```solidity
/**
 * @notice Mints tokens to a user, typically upon deposit.
 * @dev Also mints accrued interest and locks in the current global rate for the user.
 * @param _to The address to mint tokens to.
 * @param _amount The principal amount of tokens to mint.
 */
function mint(address _to, uint256 _amount) external { // TODO: Add access control (e.g., onlyVault)
    _mintAccruedInterest(_to);
    s_userInterestRate[_to] = s_interestRate;
    _mint(_to, _amount);
}
```

### `_mintAccruedInterest` Internal Function (Partial Implementation):

This internal function is responsible for calculating and minting the interest owed to a user. For now, we'll focus on one crucial part: updating the user's last updated timestamp. The full interest calculation and minting logic will be fleshed out later.

```solidity
/**
 * @dev Internal function to calculate and mint accrued interest for a user.
 * @dev Updates the user's last updated timestamp.
 * @param _user The address of the user.
 */
function _mintAccruedInterest(address _user) internal {
    // TODO: Implement full logic to calculate and mint actual interest tokens.
    // The amount of interest to mint would be:
    // current_dynamic_balance - current_stored_principal_balance
    // Then, _mint(_user, interest_amount_to_mint);

    s_userLastUpdatedTimestamp[_user] = block.timestamp;
}
```

Updating `s_userLastUpdatedTimestamp` is vital because it marks the new baseline from which future interest will accrue.

## Overriding `balanceOf` for Dynamic Balance Calculation

A core feature of this rebase token is that the user's balance reflects accrued interest without requiring constant state updates on the blockchain (which would be very gas-intensive). We achieve this by overriding the standard `balanceOf` function.

The overridden `balanceOf` will calculate the user's current balance dynamically, including any interest accrued since their `s_userLastUpdatedTimestamp`.

The formula for the new balance is essentially:
`Dynamic Balance = Stored Principal Balance * (1 + (User's Locked Interest Rate * Time Elapsed))`

Here's the implementation:

```solidity
/**
 * @notice Returns the current balance of an account, including accrued interest.
 * @param _user The address of the account.
 * @return The total balance including interest.
 */
function balanceOf(address _user) public view override returns (uint256) {
    // Get the user's stored principal balance (tokens actually minted to them).
    uint256 principalBalance = super.balanceOf(_user);

    // Calculate the growth factor based on accrued interest.
    uint256 growthFactor = _calculateUserAccumulatedInterestSinceLastUpdate(_user);

    // Apply the growth factor to the principal balance.
    // Remember PRECISION_FACTOR is used for scaling, so we divide by it here.
    return principalBalance * growthFactor / PRECISION_FACTOR;
}
```

In this function:

- `super.balanceOf(_user)` calls the original `balanceOf` function from the parent `ERC20` contract, retrieving the underlying stored balance (the principal).
- `_calculateUserAccumulatedInterestSinceLastUpdate(_user)` is an internal helper function we'll define next, which returns the growth factor `(1 + Rate * Time)` scaled by `PRECISION_FACTOR`.
- The final division by `PRECISION_FACTOR` adjusts the result back to the correct token decimal precision, as both `principalBalance` (if it uses token decimals) and `growthFactor` are effectively scaled.

## Calculating the Interest Growth Factor

The `_calculateUserAccumulatedInterestSinceLastUpdate` internal function is responsible for calculating the growth factor used in our dynamic `balanceOf`.

This factor represents `1 + (UserInterestRate * TimeElapsed)`, scaled by `PRECISION_FACTOR`.

```solidity
/**
 * @dev Calculates the growth factor due to accumulated interest since the user's last update.
 * @param _user The address of the user.
 * @return The growth factor, scaled by PRECISION_FACTOR. (e.g., 1.05x growth is 1.05 * 1e18).
 */
function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterestFactor) {
    // 1. Calculate the time elapsed since the user's balance was last effectively updated.
    uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];

    // If no time has passed, or if the user has no locked rate (e.g., never interacted),
    // the growth factor is simply 1 (scaled by PRECISION_FACTOR).
    if (timeElapsed == 0 || s_userInterestRate[_user] == 0) {
        return PRECISION_FACTOR;
    }

    // 2. Calculate the total fractional interest accrued: UserInterestRate * TimeElapsed.
    // s_userInterestRate[_user] is the rate per second.
    // This product is already scaled appropriately if s_userInterestRate is stored scaled.
    uint256 fractionalInterest = s_userInterestRate[_user] * timeElapsed;

    // 3. The growth factor is (1 + fractional_interest_part).
    // Since '1' is represented as PRECISION_FACTOR, and fractionalInterest is already scaled, we add them.
    linearInterestFactor = PRECISION_FACTOR + fractionalInterest;
    return linearInterestFactor;
}
```

**A Note on Precision:** When performing arithmetic with scaled fixed-point numbers, it's generally best to perform multiplications before divisions to maintain maximum precision. However, always be mindful of potential overflows. In our `balanceOf` function, `principalBalance * growthFactor` is done first, then division by `PRECISION_FACTOR`. This is safe if `principalBalance` and `growthFactor` are within reasonable limits such that their product doesn't exceed `uint256`'s maximum value.

