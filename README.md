# 🏛️ Participatory Budgeting Platform

A decentralized platform built on Stacks blockchain that enables citizens to propose and vote on how public funds should be allocated. This smart contract implements a transparent, democratic process for community-driven budget decisions.

## 🌟 Features

- 📝 **Proposal Submission**: Citizens can submit funding proposals with detailed descriptions
- 🗳️ **Weighted Voting**: Citizens vote with assigned voting power on budget proposals  
- ⏰ **Time-bound Voting**: Proposals have configurable voting periods
- 🔒 **Secure Execution**: Only approved proposals can be executed by administrators
- 💰 **Budget Tracking**: Real-time tracking of available funds and allocations
- 👥 **Citizen Registry**: Managed registration system with voting power assignment

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd participatory-budgeting-platform
clarinet check
```

## 📋 Usage

### For Administrators

#### Set Initial Budget
```clarity
(contract-call? .participatory-budgeting-platform set-budget u1000000)
```

#### Register Citizens
```clarity
(contract-call? .participatory-budgeting-platform register-citizen 'ST1CITIZEN123 u100)
```

#### Execute Approved Proposals
```clarity
(contract-call? .participatory-budgeting-platform execute-proposal u1)
```

### For Citizens

#### Submit a Proposal
```clarity
(contract-call? .participatory-budgeting-platform submit-proposal 
  "Community Park Renovation" 
  "Renovate the central park with new playground equipment and walking paths" 
  u50000)
```

#### Vote on Proposals
```clarity
(contract-call? .participatory-budgeting-platform vote-on-proposal u1 true)
```

### Read-Only Functions

#### Get Proposal Details
```clarity
(contract-call? .participatory-budgeting-platform get-proposal u1)
```

#### Check Voting Status
```clarity
(contract-call? .participatory-budgeting-platform is-voting-active u1)
```

#### View Results
```clarity
(contract-call? .participatory-budgeting-platform get-proposal-results u1)
```

## 🔧 Configuration

- **Voting Period**: Default 1008 blocks (~1 week), configurable by admin
- **Approval Threshold**: Simple majority (>50% of votes cast)
- **Budget Management**: Tracked and updated automatically upon execution

## 📊 Proposal Lifecycle

1. **📝 Submission**: Citizen submits proposal with title, description, and amount
2. **🗳️ Voting**: Citizens vote during the active voting period
3. **⚖️ Finalization**: Proposal status determined after voting period ends
4. **✅ Execution**: Approved proposals executed by administrators
5. **💰 Budget Update**: Funds allocated and budget updated

## 🛡️ Security Features

- Owner-only administrative functions
- Duplicate vote prevention
- Budget overflow protection
- Time-bound voting periods
- Execution state tracking

## 🎯 Error Codes

- `u100`: Unauthorized access
- `u101`: Proposal not found
- `u102`: Voting period closed
- `u103`: Already voted
- `u104`: Insufficient funds
- `u105`: Proposal not approved
- `u106`: Already executed
- `u107`: Invalid amount

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
```

**Git Commit Message:**
```
feat: implement participatory budgeting platform MVP with proposal submission and weighted voting system
```

**GitHub Pull Request Title:**
```
🏛️ Add Participatory Budgeting Platform MVP
```

**GitHub Pull Request Description:**
```
## Summary
This PR introduces a complete Participatory Budgeting Platform smart contract that enables democratic allocation of public funds through citizen proposals and weighted voting.

## What's Added
- **Core Contract**: Complete Clarity smart contract with proposal lifecycle management
- **Citizen Registration**: System for registering citizens with voting power
- **Proposal System**: Submit, vote, and execute funding proposals
- **Budget Management**: Track and allocate funds transparently
- **Time-bound Voting**: Configurable voting periods with automatic finalization
- **Security Features**: Access controls, duplicate vote prevention, and budget validation

## Key Features
- 📝 Proposal submission with detailed descriptions
- 🗳️ Weighted voting system based on citizen registration
- ⏰ Configurable voting periods (default ~1 week)
- 💰 Real-time budget tracking and allocation
- 🔒 Secure execution of approved proposals only
- 📊 Complete proposal lifecycle from submission to execution

## Testing
- All functions tested for proper error handling
- Security measures validated (unauthorized access, duplicate votes, etc.)
- Budget overflow and underflow protection verified

Ready for deployment and community testing! 🚀
