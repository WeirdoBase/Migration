# Weirdo Token Migration Contract

## Overview
This repository contains the smart contract for the migration of Weirdo tokens from an old contract to a new one. The migration involves an inflation factor to increase the total supply, implements a system for taxing late migrations, and provides measures for extracting liquidity and transferring assets to a designated treasury.

## Features
- **Token Migration:** Users can migrate their old Weirdo tokens to new ones based on a predefined inflation rate.
- **Taxation System:** Late migrants are taxed at a predefined rate to penalize delays and encourage timely migration.
- **Emergency Withdraw:** Plan B functions for sending old tokens directly to the treasury if liquidity extraction fails.
- **Robust Security:** Only the owner can perform critical actions such as ending the migration and triggering emergency measures.

## Development Setup
This project uses [Hardhat](https://hardhat.org/) as its development environment for compiling, deploying, and testing Ethereum software.

### Prerequisites
- [Node.js](https://nodejs.org/) v20
- npm (typically installed with Node.js)

### Installation
1. Clone the repository:
   ```sh
   git clone https://github.com/WeirdoBase/Migration.git
   cd Migration
   ```

2. Install the necessary dependencies:
   ```sh
   npm install
   ```

## Testing
The repository contains comprehensive tests for all smart contract functions. To run these tests and verify the functionality of the contract:

```sh
npm run test
```

## Hardhat Commands
Here are some additional Hardhat commands that might be useful:

- **Compile Contracts:**
  ```sh
  npx hardhat compile
  ```
  This command compiles the smart contracts and checks for any compilation errors.

- **Deploy Contracts:**
  ```sh
  npx hardhat run scripts/deploy.js
  ```
  Use this command to deploy contracts to a specified network. Make sure to configure your network settings in `hardhat.config.js`.

- **Local Network:**
  ```sh
  npx hardhat node
  ```
  Runs a local Ethereum network that you can use for testing and development.

## Contract Details
### Key Functions
- `migrate()`: Allows users to migrate their tokens.
- `endMigration()`: Ends the migration process when conditions are met.
- `extractEthFromLP()`: swap old weirdos collected for ETH on the burnt v2 LP and sends the ETH to treasury wallet.
- `lateMigrantDrop(recipients, amounts)`: airdrop for late migrants, including the tax on late migration voted by WeirDAO

### Events
- `MigrationInitialized`
- `WeirdoMigrated`
- `TotalMigrated`
- `MigrationClosed`
- `ETHExtracted`

For more detailed information about the functions and their uses, refer to the NatSpec comments in the contract code.

## Contribution
Contributions are welcome! If you have suggestions or issues, please feel free to open an issue or submit a pull request.

## License
This project is licensed under [MIT License](LICENSE).


