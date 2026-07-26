# 🚀 Star Protocol Setup Guide

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/ckwak54-coder/Star-protocol.git
cd Star-protocol
```

### 2. Install dependencies
```bash
npm install
```

### 3. Setup environment variables
```bash
cp .env.example .env
```

Then edit `.env` with your values:
- `SEPOLIA_RPC_URL`: Get from [Infura](https://infura.io) or [Alchemy](https://www.alchemy.com)
- `PRIVATE_KEY`: Your wallet private key (from MetaMask)
- `ETHERSCAN_API_KEY`: From [Etherscan](https://etherscan.io/apis)

## Available Commands

### Compile contracts
```bash
npm run compile
```

### Run tests
```bash
npm test
```

### Start local blockchain
```bash
npm run node
```

### Deploy to Sepolia testnet
```bash
npm run deploy:sepolia
```

### Verify contracts on Etherscan
```bash
npm run verify
```

## Project Structure

```
contracts/          # Solidity smart contracts
├── StarToken.sol
├── StarStaking.sol
├── StarGovernance.sol
└── StarAirdrop.sol

test/              # Test files (Hardhat/Mocha)
scripts/           # Deployment scripts
artifacts/         # Compiled contracts (auto-generated)
```

## Next Steps

- [ ] Tour 2: Security Fixes & Bug Corrections
- [ ] Tour 3: Unit Tests
- [ ] Tour 4: OpenZeppelin Migration
- [ ] Tour 5: Architecture Improvements
- [ ] Tour 6: Frontend Development
- [ ] Tour 7: Testnet Deployment
- [ ] Tour 8: Full Documentation

---
**Let's build Star Protocol together! 🌟**
