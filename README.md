<!-- @format -->

# Foundry Smart Contract Lottery

Lottery with true randomness using Chainlink

- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Library](#library)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Deployment to a testnet](#deployment-to-a-testnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [foundry](https://getfoundry.sh/)

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge init
```

## Quickstart

```
git clone https://github.com/gaexxx/foundry-smart-contract-lottery-f23
cd foundry-smart-contract-lottery-f23
forge build
```

# Usage

## Start a local node

```
anvil
```

## Library

Used library

```
forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit
```

## Deploy

Deploy on local node after running anvil in another terminal.

```
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $RPC_URL --private-key $PRIVATE_KEY_ANVIL --broadcast 
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet)

## Testing

```
forge test
```

or

```
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
forge coverage 
```

to get the coverage details:

```
forge coverage --report debug 
```

# Deployment to a testnet 

1. Setup environment variables

Set an `.env` like this:

```
PRIVATE_KEY_ANVIL= (you get it after running anvil)
PRIVATE_KEY_SEPOLIA= (metamask private key)
RPC_URL= (you get it after running anvil)
SEPOLIA_RPC_URL= get it here (https://alchemy.com/?a=673c802981)
ETHERSCAN_API_KEY= get it here (https://etherscan.io/)
```

and run:

```
source .env
```

1. Get sepolia testnet ETH and LINK

ETH (https://sepoliafaucet.com/)
LINK (https://faucets.chain.link/) 

2. Deploy

Deploy and verify on sepolia testnet

```
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY_SEPOLIA --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

This will setup a ChainlinkVRF Subscription for you. If you already have one, before deploying update it in the `scripts/HelperConfig.s.sol` file. It will also automatically add your contract as a consumer.

3. Register a Chainlink Automation Upkeep

After deploying the raffle contract, register a new upkeep here (https://automation.chain.link/new). Choose `Custom logic` as your trigger mechanism for automation. 

## Scripts

After deploying locally or on a testnet, you can run the scripts.

Using cast deployed locally examples:

```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key $PRIVATE_KEY_ANVIL --rpc-url $RPC_URL
cast call <RAFFLE_CONTRACT_ADDRESS> "getLengthOfPlayers()" --private-key $PRIVATE_KEY_ANVIL --rpc-url $RPC_URL
```
or on the testnet examples:

```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key $PRIVATE_KEY_SEPOLIA --rpc-url $SEPOLIA_RPC_URL
cast call <RAFFLE_CONTRACT_ADDRESS> "getLengthOfPlayers()" --private-key $PRIVATE_KEY_SEPOLIA --rpc-url $SEPOLIA_RPC_URL
```
## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Formatting

To run code formatting:

```
forge fmt
```