# Test Results Submission Template

## Contributor Information
- **GitHub Username**: @alice
- **Feature Tested**: BigInt.add

## Test Setup
- **Viem.js Version**: vX.0.0
- **Network**: TEN Testnet
- **Test Environment**: Node.js v16, Hardhat, etc.
- **Additional Setup Details**: Testing against Testnet and local Hardhat instance.

## Test Cases

| Test Case Description                          | Result  | Notes                                                                 |
|------------------------------------------------|---------|-----------------------------------------------------------------------|
| Adding two positive BigInts (basic test)       | ✅ Pass | Works as expected                                                     |
| Adding positive and negative BigInts           | ✅ Pass | Handled correctly, no errors                                          |
| Adding two very large BigInts                  | ❌ Fail | Overflow error encountered                                            |
| Edge case: Adding BigInt with zero             | ✅ Pass | Result is correct, no errors                                          |

## Additional Feedback
- Potential edge case in very large BigInt operations needs further review.

## Attachments
- [Link to code, logs, or screenshots if applicable]
