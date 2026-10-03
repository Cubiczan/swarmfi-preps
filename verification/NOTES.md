# swarmfi-preps — Lean 4 verification notes

Model: `verification/Consensus.lean` (535 lines, 37 theorems).
Toolchain: Lean 4.34.1, **core library only** (no Mathlib), compiles with
plain `~/.elan/bin/lean Consensus.lean`, exit 0, no `sorry`/`admit`.
Axiom audit (`#print axioms` on the headline theorems): only the standard
`propext`, `Classical.choice`, `Quot.sound` — no custom axioms, no `sorryAx`
(`winner_eq_long` and `no_skip_to_converged` are axiom-free). The only
compiler warnings are `if_pos`/`if_neg` deprecation notices.
No source files were modified.

## Honest accounting: what this repo actually is

The task framing ("Python, 165 source files") does not match the tree.
The application is a **Next.js / TypeScript** project:

| Category | Count | Executable decision logic? |
|---|---|---|
| `.py` files | 58 — **all** under `skills/`, **0** outside it | No — third-party agent-skill packages |
| `.ts`/`.tsx` files | 105 | Mostly UI |
| `.md` files | 107 | No — docs/prep |
| `skills/` (all files) | 361 | No — docx/pdf/pptx/xlsx tooling, blog/storyboard/market-research skill packs |
| `src/components/ui/` | 48 files | No — stock UI components |
| `src/` total | 85 files | Mostly pages/components/API glue |

The **only substantive executable decision logic** is `src/lib/swarm/`
(1,454 lines total):

- `types.ts` (85) — `Signal`, `AgentVote` types
- `consensus.ts` (234) — `computeConsensus`: weighted tally, winner,
  confidence, adversarial reduction
- `agents.ts` (826) — 8 core agents + `SentimentAgent` meta-agent,
  `runAllAgents`
- `index.ts` (309) — `runSwarmAnalysis` pipeline: fetch → agents →
  consensus → persist

`tests/test_basic.test.ts` is a 19-line placeholder that says so itself;
there are no real tests of the swarm logic. The model therefore covers
`src/lib/swarm/` plus the documented `.chp/` state machine (Part C),
which — see Finding 1 — is not implemented anywhere.

All numeric work is modelled over `ℚ` (`Rat`): the TypeScript uses IEEE
doubles, so the model verifies the *intended* arithmetic; float rounding
in the shipped code can differ in edge cases (e.g. the strict `>` on the
float two-thirds-style comparisons).

## Theorem → source mapping

### Part A — `computeConsensus` (`src/lib/swarm/consensus.ts`)

| Lean | Source |
|---|---|
| `weightOf` | `AGENT_WEIGHTS`, ll. 23–76 (Funding 1.3, Momentum 1.1, Volatility 0.8, Volume 1.2, Orderbook 1.0, Liquidation 1.4, MeanReversion 0.9, Trend 1.1, Sentiment 1.0) |
| `weightOf_funding`, `weightOf_liquidation` | spot values 1.3 / 1.4 from the table |
| `weightOf_unknown` | l. 103: unknown agent types default to weight `1.0` (`?? 1.0`) |
| `Vote`, `Tally`, `addVote`, `tally` | `AgentVote` (`types.ts` ll. 11–16); tally loop ll. 102–123: scaled weight = `weight * confidence / 100` added to the signal bucket, counter incremented, confidence accumulated |
| `addVote_counts`, `tally_counts_sum` | loop counters: long + short + neutral counts always sum to the number of list entries |
| `winner`, `winner_eq_long`, `winner_eq_short`, `winner_eq_neutral` | ll. 128–141: strict plurality wins; **any tie collapses to NEUTRAL** (characterised exactly by `winner_eq_neutral`: winner is NEUTRAL iff neither strict-plurality condition holds) |
| `totalW`, `rawConfidence` | ll. 144–156: NEUTRAL branch `neutralWeight / totalWeight * 60`; directional branch `(winning − losing) / totalWeight * 100`; zero total weight ⇒ 20 |
| `balanceRatio` | ll. 159–162: `|longCount − shortCount| / (longCount + shortCount)`, 0 when no non-neutral votes — **count-based, not weight-based** |
| `advFactor`, `advFactor_halve`, `advFactor_scale`, `advFactor_one` | ll. 164–170: ratio < 0.2 with ≥ 4 non-neutral votes ⇒ ×0.5; ratio < 0.35 with ≥ 3 ⇒ ×0.7; otherwise ×1 |
| `finalConfidence`, `confidence_bounds` | l. 168: `Math.max(10, Math.min(90, ·))` — final confidence is **always in [10, 90]**, proved for every tally |
| `consensus_empty_signal`, `consensus_empty_confidence` | empty vote list ⇒ NEUTRAL at confidence **20** (see Finding 3) |
| `fourVotes`, `fourVotes_ratio`, `fourVotes_factor` | concrete 2 LONG / 2 SHORT split: balance ratio 0 < 0.2 with 4 non-neutral votes, so the halving branch fires |

### Part B — is each participant counted once?

| Lean | Source |
|---|---|
| `countOf`, `countOf_cons`, `countOf_eq_zero` | per-agent-name occurrence count in the vote list |
| `countOf_le_one` | under a no-duplicate-agent-names hypothesis, each participant is counted ≤ 1 |
| `pipelineAgents`, `pipelineAgents_length`, `pipelineAgents_nodup` | `agents.ts`: `CORE_AGENTS` l. 793 (8 agents), `runAllAgents` l. 807, core votes ll. 811–820, `SentimentAgent` vote l. 823 — the pipeline emits exactly 9 votes, one per agent type |
| `pipeline_counted_once` | counted-once holds **for the pipeline's own vote list** — a property of the caller, not of `computeConsensus` |
| `fundingLong`, `liquidationShort`, `single_tally_weights`, `dup_tally_weights`, `single_winner_short`, `dup_winner_long`, `dup_countOf` | **COUNTEREXAMPLE** (Finding 2) |
| `Stage`, `pipelineTrace`, `pipelineTrace_exact`, `pipelineTrace_nodup`, `pipelineTrace_all_stages` | `index.ts` `runSwarmAnalysis` l. 142: fetch (l. 146) → run agents (l. 164) → consensus (l. 167) → persist signal / agent states / market snapshot (ll. 170, 187, 208). The stage sequence is exactly these four, in order, none skipped, none repeated — but see Finding 3: there is **no gate** between consensus and persist |

### Part C — the documented CHP machine (`.chp/STATE_MACHINE.md`)

States ll. 9–18; transitions ll. 27–36. `Reach` is a locally defined
reflexive-transitive closure (core Lean has no `ReflTransGen`).

| Lean | Claim |
|---|---|
| `step_locked_iff` | LOCKED is reachable in one step **only** from PROVISIONAL_LOCK, and that step carries a third-party `ConfirmToken` (the document's CONFIRM) |
| `step_converged` | CONVERGED is entered only from LOCKED |
| `step_provisionalLock` | PROVISIONAL_LOCK is entered only from PROVISIONAL |
| `reach_locked_needs_provisionalLock` | any run reaching LOCKED passed through PROVISIONAL_LOCK |
| `reach_converged_needs_locked` | any run reaching CONVERGED passed through LOCKED |
| `reach_provisionalLock_needs_provisional` | any run reaching PROVISIONAL_LOCK passed through PROVISIONAL |
| `no_skip_to_converged` | a run from EXPLORING to CONVERGED passed through PROVISIONAL, PROVISIONAL_LOCK **and** LOCKED — no skipping in the documented machine. The Any → HALT / Any → UNRESOLVED escapes cannot manufacture LOCKED or CONVERGED because they target only HALT / UNRESOLVED |

So the *documented* machine has the claimed properties: legal transitions
only, no skipped stages, and the gated action (LOCKED) requires its check
(the third-party CONFIRM step out of PROVISIONAL_LOCK). The problem is
that none of it is code — Finding 1.

## Findings / discrepancies / risks

1. **The CHP governance layer is documentation only.** No CHP state name
   (`EXPLORING`, `PROVISIONAL_LOCK`, …) occurs anywhere in `src/`; no code
   reads `.chp/R0_CONFIG.yaml` or enforces the R0 gate; the GitHub CHP
   workflow only checks that the YAML has `r0_gate`/`foundation` sections
   and that three markdown files exist. Yet `README.md` ll. 242–267 claim
   the repo is "hardened" with CHP, an R0 gate, a mandatory devil's
   advocate, the state machine and third-party validation. **README
   overstates the implementation: none of it executes.** Part C verifies
   the document, not the product — which is exactly the divergence.

2. **`computeConsensus` does not count each participant once —
   counterexample proved.** One FundingAgent LONG @100 (scaled weight
   13/10) loses to one LiquidationAgent SHORT @100 (7/5):
   `single_winner_short`. Duplicate the *same* FundingAgent vote and
   longW doubles to 13/5, flipping the winner to LONG:
   `dup_tally_weights`, `dup_winner_long`, and
   `dup_countOf … = 2`. Nothing in the tally loop deduplicates by agent.
   Counted-once holds only because `runAllAgents` hard-codes one call
   per agent (`pipeline_counted_once`). Any other caller — e.g. the
   unauthenticated POST `/api/swarm/consensus` route, retries, or a
   future agent list with a repeated type — silently double-counts.
   Relatedly, the loop's `lastSignals[agentType]` entry is overwritten
   by a duplicate while *both* copies' weights count, so the reported
   per-agent signal and the tallied weight can disagree.

3. **No gate between consensus and persistence; empty runs persist a
   tradeable-looking signal.** `runSwarmAnalysis` (`index.ts` l. 167 →
   l. 170) persists whatever consensus returns: no confidence floor, no
   CHP/R0/foundation check, no empty-vote check. With zero votes the
   pipeline produces and persists **NEUTRAL at confidence 20**
   (`consensus_empty_signal`, `consensus_empty_confidence`). Compounding
   this, market-data fetching uses `Promise.allSettled`
   (`buildMarketDataBundle`): every fetch can fail and the pipeline
   still proceeds on null/empty data and persists the result.

4. **The SentimentAgent is a meta-vote counted as a peer.**
   `sentimentAgent` (`agents.ts` l. 707) derives its LONG/SHORT from the
   other agents' votes, and its vote is then tallied alongside theirs
   (l. 823) at weight 1.0 — the emerging consensus is counted twice:
   once in the core votes, once in the meta-vote that summarises them.

5. **Unvalidated inputs.** `types.ts` l. 11–16 documents confidence as
   0–100, but `computeConsensus` never checks it: scaled weight is linear
   in confidence, so a confidence of 250 (or negative) counts
   proportionally. Likewise any agent-name string is accepted, silently
   weighted 1.0 (`weightOf_unknown`) instead of being rejected against
   the `AGENT_WEIGHTS` table.

6. **Ties are silent NEUTRALs.** Winner selection is strict plurality;
   an exact weighted tie (including 2 LONG vs 2 SHORT by weight) yields
   NEUTRAL (`winner_eq_neutral`), indistinguishable downstream from a
   genuinely neutral consensus — and the adversarial halving still
   applies on top (`fourVotes_factor`).

7. **STATE_MACHINE.md ambiguity.** REFRAME_REQUIRED's entry condition
   (foundation < 70) appears only in the thresholds section (l. 42), not
   in the transition list (ll. 27–36). The model includes
   EXPLORING → REFRAME_REQUIRED; if that edge is not intended, Part C's
   no-skip results are unaffected (the edge cannot reach LOCKED or
   CONVERGED except via the full chain), but the document should say so
   explicitly. Separately, `.chp/R0_CONFIG.yaml` statically sets all
   four R0 checks to `true` — as documentation of a gate that never
   runs, it asserts its own passing.
