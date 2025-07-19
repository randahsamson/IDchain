# 🆔 IDchain - Decentralized KYC Profile System

A Clarity smart contract for creating reusable, verified identity NFTs on the Stacks blockchain. IDchain enables users to create KYC profiles that can be verified by authorized entities and reused across different platforms.

## 🌟 Features

- **🔐 Decentralized Identity**: Create and manage KYC profiles on-chain
- **✅ Multi-level Verification**: Support for different verification levels
- **👥 Authorized Verifiers**: Only approved entities can verify profiles
- **📝 Profile Attributes**: Add and verify specific identity attributes
- **🔄 Reusable Profiles**: Use verified identity across multiple platforms
- **⏸️ Profile Management**: Suspend/activate profiles as needed

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run Clarinet commands to test and deploy

```bash
clarinet check
```

```bash
clarinet test
```

```bash
clarinet deploy
```

## 📖 Usage

### Creating a Profile

Users can create their KYC profile by providing metadata:

```clarity
(contract-call? .IDchain create-profile "QmHash123...")
```

### Adding Verifiers (Contract Owner Only)

```clarity
(contract-call? .IDchain add-verifier 'SP1234... u3)
```

### Verifying a Profile

Authorized verifiers can verify profiles with specific levels:

```clarity
(contract-call? .IDchain verify-profile u1 u2)
```

### Adding Profile Attributes

Users can add additional attributes to their profiles:

```clarity
(contract-call? .IDchain add-profile-attribute u1 "email" "verified@example.com")
```

### Checking Verification Status

```clarity
(contract-call? .IDchain is-profile-verified u1 u2)
```

## 🔍 Read-Only Functions

- `get-profile`: Get profile details by ID
- `get-user-profile`: Get profile by user principal
- `get-profile-attribute`: Get specific profile attribute
- `is-profile-verified`: Check if profile meets verification level
- `is-verifier-authorized`: Check if address is authorized verifier
- `get-profile-count`: Get total number of profiles

## 🛡️ Security Features

- **Access Control**: Only profile owners can modify their data
- **Verifier Authorization**: Only approved verifiers can verify profiles
- **Contract Pause**: Emergency pause functionality
- **Profile Suspension**: Ability to suspend compromised profiles

## 📊 Verification Levels

- **Level 0**: Unverified (default)
- **Level 1**: Basic verification
- **Level 2**: Enhanced verification  
- **Level 3**: Premium verification

## 🔧 Error Codes

- `u100`: Not authorized
- `u101`: Profile already exists
- `u102`: Profile not found
- `u103`: Invalid verification level
- `u104`: Insufficient verification
- `u105`: Verifier not authorized
- `u106`: Profile suspended
- `u107`: Invalid data

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
