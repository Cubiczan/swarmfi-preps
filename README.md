# SwarmFi Perps

AI agent swarm intelligence platform that analyzes perpetual futures markets in real-time using the dYdX v4 Indexer API -- nine specialized agents independently evaluate market conditions through stigmergic coordination and adversarial weighted consensus to produce actionable LONG/SHORT/NEUTRAL trading signals.

[![Next.js](https://img.shields.io/badge/Next.js-16-black?logo=next.js)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5-blue?logo=typescript)](https://typescriptlang.org/)
[![dYdX](https://img.shields.io/badge/dYdX-v4-6967FF?logo=dydx)](https://dydx.exchange/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

SwarmFi Perps is a zero-token AI agent swarm intelligence platform designed for perpetual futures market analysis. It leverages the publicly accessible dYdX v4 Indexer API to gather real-time market data -- orderbook depth, recent trades, OHLCV candles, and historical funding rates -- and feeds it to nine independent specialist agents that each evaluate a different aspect of market conditions.

The platform is built on the principle of **stigmergic coordination**, a biological coordination mechanism where agents communicate indirectly through shared state (a stigmergy board) rather than direct messaging. Each agent casts a weighted vote based on its domain expertise, and an adversarial consensus algorithm combines these votes into a single trading signal. When bullish and bearish agents are evenly split, confidence is automatically halved to reduce false signals.

SwarmFi Perps was built as a US-friendly alternative to Hyperliquid-based tools, taking advantage of dYdX's richer, unrestricted data set that includes sparklines, historical PnL, rewards tracking, and vault analytics -- capabilities not available through geo-restricted APIs.

## Architecture

```
+-------------------------------------------------------------------+
|                     Frontend (Next.js 16)                          |
|  +-------------+ +------------+ +------------+ +---------------+  |
|  | Consensus   | | Agent      | | Price      | | Order Book    |  |
|  | Signal      | | Grid       | | Chart      | | + Trades      |  |
|  +------+------+ +------+-----+ +------+-----+ +------+--------+  |
|         +----------------+---------+---------------+               |
|                         | API                                     |
+-------------------------------------------------------------------+
|                     Backend (API Routes)                           |
|  +------------------------------+-------------------------------+ |
|  |              Swarm Engine                                    | |
|  |  +-------------+  +-----------+  +------------------------+  | |
|  |  | 9 Agents    |->| Consensus |->| Stigmergy Board         |  | |
|  |  | (parallel)  |  | Algorithm |  | (shared state)           |  | |
|  |  +-------------+  +-----------+  +------------------------+  | |
|  +------------------------------+-------------------------------+ |
|                         |                                        |
|  +------------------------------+-------------------------------+ |
|  |           dYdX v4 Indexer API (Public)                        | |
|  |  Markets | Orderbook | Trades | Candles | Funding            | |
|  +--------------------------------------------------------------+ |
+-------------------------------------------------------------------+
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router) |
| Language | TypeScript 5 |
| Styling | Tailwind CSS 4 + shadcn/ui |
| State Management | Zustand |
| Database | SQLite + Prisma ORM |
| Animation | Framer Motion |
| Charts | Recharts + Custom SVG |
| Data Source | dYdX v4 Indexer API (public, US-accessible) |

## Key Features

- **Nine Specialized Market Agents** -- FundingAgent, MomentumAgent, VolatilityAgent, VolumeAgent, OrderbookAgent, LiquidationAgent, MeanReversionAgent, TrendAgent, and SentimentAgent (meta-agent). Each agent independently analyzes a specific dimension of market data and produces a weighted vote with detailed reasoning.

- **Adversarial Weighted Consensus** -- A novel consensus algorithm where each agent's vote is scaled by both its configured reliability weight and its confidence score. When bullish and bearish agents are evenly split (adversarial balance ratio below 0.2), overall confidence is halved to suppress false signals during uncertain market conditions.

- **Stigmergic Coordination** -- Agents share state through a stigmergy board that persists across analysis runs. The board tracks last signals, volatility regime (LOW/NORMAL/HIGH), liquidation risk level (LOW/MEDIUM/HIGH), and average confidence -- enabling agents to incorporate cross-run memory into their analysis.

- **Real-Time dYdX v4 Data** -- Direct integration with the dYdX v4 Indexer API for live market metadata, orderbook depth at multiple levels, trade history with buy/sell direction, OHLCV candle data, and historical funding rates including annualized calculations.

- **Comprehensive Dashboard** -- Single-page dashboard displaying the consensus signal with a confidence ring, a 3x3 agent grid showing individual agent votes, candlestick price charts, funding rate history, bid/ask orderbook depth visualization, and a historical signal log.

- **US-Friendly Data Access** -- Built on dYdX's publicly accessible Indexer API with no geo-restrictions, making it available to US-based users unlike Hyperliquid's blocked API.

## Getting Started

### Prerequisites

- Bun 1.0+ (recommended) or Node.js 18+
- A modern web browser

### Installation

```bash
# Clone the repository
git clone https://github.com/icohangar-ops/swarmfi-perps.git
cd swarmfi-perps

# Install dependencies
bun install

# Set up the database
bun run db:push

# Start the development server
bun run dev
```

The application will be available at `http://localhost:3000`.

### Environment Variables

Create a `.env` file in the project root:

```env
# Database (SQLite -- default is fine for development)
DATABASE_URL="file:./dev.db"
```

## Usage

### Running the Application

```bash
# Development mode
bun run dev

# Production build
bun run build
bun run start
```

### Using the Dashboard

1. Select a market from the dropdown (e.g., BTC-USD, ETH-USD, SOL-USD)
2. Click "Run Swarm" to execute all nine agents in parallel
3. Review the consensus signal -- LONG, SHORT, or NEUTRAL with confidence score (0-100)
4. Examine individual agent votes in the 3x3 agent grid
5. Explore price charts, funding history, and orderbook depth
6. Enable auto-refresh for continuous monitoring

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dydx/markets` | dYdX market metadata proxy |
| GET | `/api/dydx/orderbook?ticker=BTC-USD` | Real-time orderbook depth |
| GET | `/api/dydx/trades?ticker=BTC-USD` | Recent trade history |
| GET | `/api/dydx/candles?ticker=BTC-USD` | OHLCV candle data |
| GET | `/api/dydx/funding?ticker=BTC-USD` | Historical funding rates |
| GET | `/api/swarm/agents?ticker=BTC-USD` | Agent state data |
| GET | `/api/swarm/consensus?ticker=BTC-USD` | Run swarm analysis / get result |
| GET | `/api/swarm/history` | Historical consensus signals |

### The Nine Agents

| Agent | Signal Source | Weight |
|-------|--------------|--------|
| FundingAgent | Historical funding rates, consecutive direction | 1.3 |
| MomentumAgent | Price vs SMA crossovers, consecutive candles | 1.1 |
| VolatilityAgent | Hourly returns std dev, range compression | 0.8 |
| VolumeAgent | Volume ratio (recent/avg), buy/sell imbalance | 1.2 |
| OrderbookAgent | Bid/ask depth at multiple levels, spread analysis | 1.0 |
| LiquidationAgent | Funding + volatility + wick rejection patterns | 1.4 |
| MeanReversionAgent | Z-score distance from price mean | 0.9 |
| TrendAgent | Multi-timeframe SMA alignment | 1.1 |
| SentimentAgent | Meta-agent synthesizing all other agents' votes | 1.0 |

## Project Structure

```
swarmfi-perps/
├── package.json                # Dependencies and scripts
├── bun.lock                    # Lock file
├── tsconfig.json               # TypeScript configuration
├── tailwind.config.ts          # Tailwind CSS configuration
├── components.json             # shadcn/ui configuration
├── prisma/
│   └── schema.prisma           # SQLite schema for signal history
├── public/
│   ├── logo.svg                # SwarmFi logo
│   └── demo/                   # Screenshots and demo videos
├── src/
│   ├── app/
│   │   ├── layout.tsx          # Root layout
│   │   ├── page.tsx            # Main dashboard page
│   │   ├── globals.css         # Global styles
│   │   └── api/
│   │       ├── dydx/
│   │       │   ├── markets/route.ts    # Market metadata proxy
│   │       │   ├── orderbook/route.ts  # Orderbook depth
│   │       │   ├── trades/route.ts     # Recent trades
│   │       │   ├── candles/route.ts    # OHLCV data
│   │       │   └── funding/route.ts    # Funding rates
│   │       ├── swarm/
│   │       │   ├── agents/route.ts     # Agent state
│   │       │   ├── consensus/route.ts  # Consensus endpoint
│   │       │   └── history/route.ts    # Signal history
│   │       └── route.ts                # Root API
│   ├── components/
│   │   ├── ui/                   # shadcn/ui primitives
│   │   └── dashboard/
│   │       ├── Header.tsx        # Market selector + controls
│   │       ├── ConsensusSignal.tsx   # Main signal display
│   │       ├── AgentSwarmGrid.tsx    # 3x3 agent card grid
│   │       ├── SwarmControls.tsx     # Auto-refresh, thresholds
│   │       ├── PriceChart.tsx        # Candlestick chart
│   │       ├── FundingChart.tsx      # Funding rate history
│   │       ├── OrderBook.tsx         # Bid/ask depth
│   │       ├── RecentTrades.tsx      # Trade feed
│   │       └── SignalHistory.tsx     # Past consensus signals
│   └── lib/
│       ├── dydx.ts              # dYdX v4 Indexer API client
│       ├── store.ts             # Zustand state management
│       ├── hooks.ts             # Data fetching hooks + mocks
│       ├── db.ts                # Prisma database client
│       ├── utils.ts             # Utility functions
│       └── swarm/
│           ├── types.ts         # Type definitions
│           ├── agents.ts        # 9 specialized agent implementations
│           ├── consensus.ts     # Adversarial weighted consensus
│           └── index.ts         # Full pipeline orchestrator
```

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run `bun run lint` to check for style issues
5. Commit your changes with descriptive messages
6. Open a Pull Request against the `main` branch

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full text.

---

## CHP Governance

This repository is hardened with the [Consensus Hardening Protocol (CHP)](https://codeberg.org/cubiczan/consensus-hardening-protocol), Cubiczan's decision-governance layer for multi-agent AI systems.

### Protocol Layers
- **R0 Gate**: All decisions must pass Solvable, Scoped, Valid, Worth_it checks
- **Foundation Disclosure**: 1-3 weakest assumptions, 1-2 invalidation conditions, 1 key vulnerability
- **Adversarial Layer**: Mandatory devil's advocate at Phase 0 and Round 3
- **State Machine**: EXPLORING → PROVISIONAL → PROVISIONAL_LOCK → LOCKED
- **Third-Party Validation**: Independent CONFIRM/REJECT before lock

### Domain Configuration
- **Category**: Finance (Trading)
- **Foundation Threshold**: 85
- **CFO Accuracy Guard**: Enabled

### Compliance Artifacts
| File | Purpose |
|------|---------|
| `.chp/STATE_MACHINE.md` | Decision state transitions |
| `.chp/R0_CONFIG.yaml` | Domain-calibrated thresholds |
| `.chp/ADVERSARIAL_PROMPTS.md` | Standardized challenge templates |
| `.chp/CHP_COMPLIANCE.md` | Compliance tracking & audit trail |

### CHP Version
cognitive-mesh-orchestrator 0.1.0 | [Protocol Docs](https://codeberg.org/cubiczan/consensus-hardening-protocol)


---

## Propagation decisions (DeFi wave B)

- **Row 4 (calibration feedback loop — Brier score → softmax weights) — reversed.**
  The row's own settled condition fires: Brier weights are statistically
  empty until enough outcomes resolve, and this desk has no outcome stream
  at all — the nine specialist agents vote LONG/SHORT/NEUTRAL through
  `src/lib/swarm/agents.ts` and `src/lib/swarm/consensus.ts` renders the
  consensus live, but no trade execution, position persistence, or
  settlement feed exists anywhere in `src/` (verified by search this wave),
  so there is nothing to score against. The current hand-picked reliability
  priors (`AGENT_WEIGHTS` in `src/lib/swarm/consensus.ts`: Funding 1.3 …
  Volatility 0.8) beat noise under the row's own standard. Revisit when the
  desk persists its own recommendations and resolves them against realized
  perp outcomes on a dense, objective cadence — then port pythia's
  `update_weights` loop (canonical `pythia_consensus.engine.py`) to score
  the nine agents and feed the weights back between runs.
