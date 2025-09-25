# Gaming Arcade Smart Contract

A Stacks blockchain smart contract that simulates a gaming arcade where players can operate arcade machines using tokens and earn ticket rewards based on their gameplay performance.

## Overview

This contract implements a decentralized arcade system where:
- Players insert tokens into arcade machines to play games
- Ticket rewards are calculated based on gameplay duration, machine difficulty, and multipliers
- The arcade owner can manage machines and handle emergency situations
- Players can cash out their tokens or receive emergency refunds during power outages

## Features

### Core Functionality
- **Token System**: Uses a fungible token (`arcade-ticket`) for all transactions
- **Multiple Machines**: Support for different arcade machines with varying difficulties and reward multipliers
- **Dynamic Rewards**: Ticket earnings based on tokens inserted, time played, and machine characteristics
- **Emergency Management**: Power outage system with partial refunds

### Machine Types (Default Setup)
1. **Retro Games** - Difficulty: 3, Multiplier: 75%
2. **VR Station** - Difficulty: 6, Multiplier: 110%
3. **Tournament Arena** - Difficulty: 9, Multiplier: 150%

## Contract Functions

### Public Functions

#### `setup-arcade()`
Initializes the arcade with 800,000 tokens for the owner and installs the default three arcade machines.

#### `install-machine(game-type, difficulty, multiplier)`
**Owner Only** - Installs a new arcade machine.
- `game-type`: String description (max 28 characters)
- `difficulty`: Integer between 1-10
- `multiplier`: Percentage between 50-200

#### `insert-tokens(machine-id, token-count)`
Insert tokens into a specific machine to start playing.
- Transfers tokens from player to contract
- Awards any pending tickets from previous sessions
- Updates player's session data

#### `cash-out-tokens(machine-id, token-count)`
Cash out tokens from a machine session.
- Awards final tickets before withdrawal
- Returns specified tokens to player
- Updates session balance

#### `power-outage-refund(machine-id)`
Emergency refund during power outages.
- Only available when power outage is active
- Returns 92% of tokens (8% maintenance fee)
- Clears player session

#### `trigger-power-outage(outage-active)`
**Owner Only** - Toggle power outage status for emergency situations.

### Read-Only Functions

#### `get-player-session(player, machine-id)`
Returns current session data for a player on a specific machine.

#### `get-machine-info(machine-id)`
Returns complete information about a specific arcade machine.

#### `get-arcade-status()`
Returns overall arcade statistics including total tokens and outage status.

## Ticket Reward System

Tickets are calculated using the formula:
```
tickets = (tokens_inserted × games_played × tickets_per_play × machine_multiplier) / (total_machine_tokens × 100)
```

Where:
- `games_played` = blocks elapsed since last play
- `tickets_per_play` = 4 (configurable)
- Machine multiplier varies by machine type
- Total machine tokens affects the reward pool

## Error Codes

- `u101`: Not owner
- `u102`: Insufficient tokens
- `u103`: No machine access
- `u104`: Machine broken
- `u105`: Invalid machine
- `u106`: Invalid difficulty (must be 1-10)
- `u107`: Invalid multiplier (must be 50-200)
- `u108`: Invalid game type

## Usage Examples

### For Players

1. **Start Playing**:
   ```clarity
   (contract-call? .arcade insert-tokens u0 u100) ;; Insert 100 tokens into machine 0
   ```

2. **Check Session**:
   ```clarity
   (contract-call? .arcade get-player-session 'SP1... u0) ;; Check session on machine 0
   ```

3. **Cash Out**:
   ```clarity
   (contract-call? .arcade cash-out-tokens u0 u50) ;; Cash out 50 tokens from machine 0
   ```

### For Arcade Owner

1. **Install New Machine**:
   ```clarity
   (contract-call? .arcade install-machine "Racing Game" u5 u90)
   ```

2. **Trigger Emergency**:
   ```clarity
   (contract-call? .arcade trigger-power-outage true)
   ```

## Security Features

- **Owner Validation**: Critical functions restricted to arcade owner
- **Input Validation**: Comprehensive checks for all parameters
- **Balance Checks**: Prevents overdrawing tokens
- **Machine Status**: Checks if machines are working before allowing play
- **Emergency Protocols**: Power outage system for unusual circumstances

## Technical Specifications

- **Language**: Clarity (Stacks blockchain)
- **Token Standard**: Fungible Token (FT)
- **Block-based Timing**: Uses Stacks block height for game duration
- **Data Storage**: Maps for machines, player sessions, and variables for global state

## Constants and Limits

- Max Difficulty: 10
- Min Difficulty: 1
- Max Multiplier: 200%
- Min Multiplier: 50%
- Game Type Length: 28 characters
- Default Tickets Per Play: 4
- Outage Maintenance Fee: 8%

## Deployment Notes

1. The contract owner is set to the transaction sender during deployment
2. Call `setup-arcade()` after deployment to initialize the system
3. The owner receives 800,000 initial tokens for arcade operations
4. Default machines are automatically installed during setup

## Future Enhancements

Potential improvements could include:
- Achievement systems
- Tournament modes
- Machine maintenance schedules
- Dynamic difficulty adjustment
- Player statistics tracking
- Social features and leaderboards
