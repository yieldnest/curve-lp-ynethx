# Tokenized Strategy Mix for Yearn V3 strategies AND a Connector for ynETHx 

This repo will allow you to write, test and deploy V3 "Tokenized Strategies" using [Foundry](https://book.getfoundry.sh/).

You will only need to override the three functions in Strategy.sol of `_deployFunds`, `_freeFunds` and `_harvestAndReport`. With the option to also override `_tend`, `_tendTrigger`, `availableDepositLimit`, `availableWithdrawLimit` and `_emergencyWithdraw` if desired.

For a more complete overview of how the Tokenized Strategies work please visit the [TokenizedStrategy Repo](https://github.com/yearn/tokenized-strategy).

### Connector

The `Connector.sol` interfaces between Yieldnest's ynETHx vault and the Yearn strategy. It allows deposits into the Yearn strategy with underlying assets instead of its main asset which is a Curve LP token. Additionally, the `rate()` function returns the price per share (PPS) of the Yearn strategy, denominated in ETH.

## How to start

### Requirements

- First you will need to install [Foundry](https://book.getfoundry.sh/getting-started/installation).
NOTE: If you are on a windows machine it is recommended to use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)
- Install [Node.js](https://nodejs.org/en/download/package-manager/)

### Set your environment Variables

Use the `.env.example` template to create a `.env` file and store the environement variables. You will need to populate the `RPC_URL` for the desired network(s). RPC url can be obtained from various providers, including [Ankr](https://www.ankr.com/rpc/) (no sign-up required) and [Infura](https://infura.io/).

Use .env file

1. Make a copy of `.env.example`
2. Add the value for `ETH_RPC_URL` and other example vars
     NOTE: If you set up a global environment variable, that will take precedence.

### Build the project

```sh
forge build
```

Run tests

```sh
forge test --match-contract Connector --fork-url [RPC_URL]
```
