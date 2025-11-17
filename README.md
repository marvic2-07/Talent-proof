# Talent-Proof (SkillChain)
### Decentralized Talent Verification Smart Contract  
Built on the Stacks Blockchain — Powered by Clarity

## Overview
**Talent-Proof (SkillChain)** is a decentralized protocol designed to register 
professionals, submit their skills, and verify them on-chain through authorized 
verifiers. The system maintains immutable talent records and reputation scores, 
enabling transparent skill validation without centralized intermediaries.



##  Features

###  Talent Registry
- Register a talent with name and profession.
- Automatically timestamped for authenticity.
- Stores reputation score, owned by the talent creator.

###  Skill Submission
- Each skill is tied to a talent ID.
- Only the talent owner can submit skills.
- Prevents duplicate submissions.

###  Verification System
- Only approved verifiers can verify skills.
- Verified skills increase reputation.
- Verification revocation supported (admin or verifying principal).

###  Admin Controls
- Add verifiers  
- Remove verifiers  
- Manage ecosystem trust layer  

### 📡 Read-Only Endpoints
| Function | Purpose |
|----------|----------|
| `get-talent` | Fetch talent details |
| `get-skill` | Fetch skill details |
| `get-next-talent-id` | View next ID counter |
| `get-talent-reputation` | See reputation score |
| `is-verifier` | Check verifier status |


##  Architecture

### Data Structures
- `talents` → Stores talent profile & reputation  
- `skills` → Skill verification status + verifier metadata  
- `verifiers` → Approved verifier list  

### Reputation Model
- +1 reputation per verified skill  
- -1 reputation if verification is revoked  

##  Events Logged
- `talent-registered`
- `skill-submitted`
- `skill-verified`
- `verifier-updated`

## Development

### Compile
