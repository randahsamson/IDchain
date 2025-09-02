# 🆔 IDchain - Decentralized KYC Profile System

A Clarity smart contract for creating reusable, verified identity NFTs on the Stacks blockchain. IDchain enables users to create KYC profiles that can be verified by authorized entities and reused across different platforms.

## 🌟 Features

- **🔐 Decentralized Identity**: Create and manage KYC profiles on-chain
- **✅ Multi-level Verification**: Support for different verification levels
- **👥 Authorized Verifiers**: Only approved entities can verify profiles
- **📝 Profile Attributes**: Add and verify specific identity attributes
- **🔄 Reusable Profiles**: Use verified identity across multiple platforms
- **⏸️ Profile Management**: Suspend/activate profiles as needed
- **⏱️ Profile Expiration & Renewal**: Automated expiration tracking with renewal workflows
- **📈 Reputation System**: Advanced reputation scoring with endorsements
- **📚 History Tracking**: Comprehensive audit trails for all profile activities

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

### Profile Renewal Workflow

Request profile renewal (available 2 days before expiration):

```clarity
(contract-call? .IDchain request-profile-renewal u1)
```

Verifiers can approve renewals:

```clarity
(contract-call? .IDchain approve-profile-renewal u1)
```

Check profile expiration status:

```clarity
(contract-call? .IDchain is-profile-expired u1)
(contract-call? .IDchain is-profile-renewable u1)
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

## ⚡ System Features

### Profile Expiration & Renewal System
- **Automated Tracking**: Profiles expire after ~1 year (configurable)
- **Grace Period**: 1-week grace period for late renewals
- **Early Renewal**: Renew profiles 2 days before expiration
- **Verifier Approval**: Structured approval workflow for renewals
- **Auto-Renewal Support**: Users can enable auto-renewal preferences
- **Comprehensive Analytics**: Track renewal statistics and history

For detailed information, see [PROFILE_EXPIRATION_SYSTEM.md](PROFILE_EXPIRATION_SYSTEM.md)

### Reputation System
- **Trust Scoring**: Calculate weighted trust scores
- **Profile Endorsements**: Community-based endorsements
- **Verifier Reputation**: Track verifier performance
- **Reputation Thresholds**: Configurable reputation levels

### History & Analytics
- **Complete Audit Trail**: Track all profile activities
- **History Analytics**: Analyze activity patterns
- **Access Control**: Granular history access permissions

## 🔧 Error Codes

### Core Errors
- `u100`: Not authorized
- `u101`: Profile already exists
- `u102`: Profile not found
- `u103`: Invalid verification level
- `u104`: Insufficient verification
- `u105`: Verifier not authorized
- `u106`: Profile suspended
- `u107`: Invalid data

### System Errors
- `u108`: History not found
- `u109`: Invalid history type
- `u110`: Invalid reputation score
- `u111`: Endorsement exists
- `u112`: Self endorsement not allowed
- `u113`: Insufficient reputation

### Renewal System Errors
- `u114`: Profile expired
- `u115`: Renewal pending
- `u116`: Not renewable
- `u117`: Renewal not found

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
