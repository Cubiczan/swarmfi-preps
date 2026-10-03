/-
  SwarmFi Preps — formal model of the executable core.

  The repository's only real decision flow is the swarm consensus pipeline:

    src/lib/swarm/index.ts     runSwarmAnalysis  (fetch → agents → consensus → persist)
    src/lib/swarm/agents.ts    runAllAgents      (8 core agents + SentimentAgent meta-vote)
    src/lib/swarm/consensus.ts computeConsensus  (adversarial weighted voting)

  Part A models `computeConsensus` (consensus.ts ll. 84–208) exactly:
  weights from `AGENT_WEIGHTS` (ll. 23–76, unknown types default to 1.0),
  scaled weight = weight * confidence / 100, strict-plurality winner with
  ties collapsing to NEUTRAL, branch confidence, the adversarial
  count-balance reduction (ll. 151–165), and the [10, 90] clamp (l. 168).

  TS uses IEEE floats; the model uses `Rat`. Every weight in the code is an
  exact decimal (1.3, 1.1, 0.8, …) and every threshold an exact decimal
  (0.2, 0.35), so the rational model is faithful except for float rounding
  at exact boundaries — see NOTES.md.

  Part B settles "each participant counted once": TRUE for the pipeline's
  own vote list (agents.ts ll. 793–826), FALSE for `computeConsensus` as a
  function (duplicated agent types are counted repeatedly — a concrete
  counterexample flips the outcome).

  Part C models the CHP state machine documented in .chp/STATE_MACHINE.md.
  No state of that machine occurs anywhere in src/ (grep-verified); the
  theorems are about the *documented* machine only.
-/

/-! ## Part A — votes, weights, tally, consensus -/

/-- `Signal` in src/lib/swarm/types.ts l. 9. -/
inductive Signal where
  | long | short | neutral
  deriving DecidableEq, Repr

/-- `AgentVote` in types.ts ll. 11–16 (`reasoning` is decision-irrelevant
    and omitted). `confidence` is *not* range-checked by computeConsensus;
    the type comment says 0–100 but the function accepts any number. -/
structure Vote where
  agent : String
  signal : Signal
  conf : Rat
  deriving Repr

/-- `AGENT_WEIGHTS` (consensus.ts ll. 23–76). Unknown agent types fall back
    to 1.0 (`?? 1.0`, l. 103). -/
def weightOf (agent : String) : Rat :=
  if agent = "FundingAgent" then 13 / 10
  else if agent = "MomentumAgent" then 11 / 10
  else if agent = "VolatilityAgent" then 4 / 5
  else if agent = "VolumeAgent" then 6 / 5
  else if agent = "OrderbookAgent" then 1
  else if agent = "LiquidationAgent" then 7 / 5
  else if agent = "MeanReversionAgent" then 9 / 10
  else if agent = "TrendAgent" then 11 / 10
  else if agent = "SentimentAgent" then 1
  else 1

theorem weightOf_funding : weightOf "FundingAgent" = 13 / 10 := by rfl
theorem weightOf_liquidation : weightOf "LiquidationAgent" = 7 / 5 := by rfl

/-- The `?? 1.0` fallback: an unregistered agent type votes at full weight. -/
theorem weightOf_unknown : weightOf "RogueAgent" = 1 := by rfl

/-- Accumulator of the tally loop (consensus.ts ll. 95–123). -/
structure Tally where
  longW : Rat
  shortW : Rat
  neutralW : Rat
  longC : Nat
  shortC : Nat
  neutralC : Nat
  totalConf : Rat
  deriving Repr

def Tally.zero : Tally := ⟨0, 0, 0, 0, 0, 0, 0⟩

/-- One iteration of the loop (consensus.ts ll. 102–123):
    scaled weight = weight * confidence / 100, added to the signal's
    bucket; the signal's counter incremented; confidence accumulated.
    Nothing deduplicates by `agent`. -/
def addVote (t : Tally) (v : Vote) : Tally :=
  let scaled := weightOf v.agent * (v.conf / 100)
  match v.signal with
  | .long => { t with longW := t.longW + scaled, longC := t.longC + 1, totalConf := t.totalConf + v.conf }
  | .short => { t with shortW := t.shortW + scaled, shortC := t.shortC + 1, totalConf := t.totalConf + v.conf }
  | .neutral => { t with neutralW := t.neutralW + scaled, neutralC := t.neutralC + 1, totalConf := t.totalConf + v.conf }

def tally (votes : List Vote) : Tally := votes.foldl addVote Tally.zero

/-- Each tally step increments exactly one counter by exactly one. -/
theorem addVote_counts (t : Tally) (v : Vote) :
    (addVote t v).longC + (addVote t v).shortC + (addVote t v).neutralC
      = t.longC + t.shortC + t.neutralC + 1 := by
  unfold addVote
  cases h : v.signal <;> simp <;> omega

/-- The counters partition the vote list: every list entry is counted
    exactly once *as an entry* (duplicated agents included). -/
theorem tally_counts_sum (votes : List Vote) :
    (tally votes).longC + (tally votes).shortC + (tally votes).neutralC
      = votes.length := by
  have h : ∀ (acc : Tally) (vs : List Vote),
      (vs.foldl addVote acc).longC + (vs.foldl addVote acc).shortC
        + (vs.foldl addVote acc).neutralC
        = acc.longC + acc.shortC + acc.neutralC + vs.length := by
    intro acc vs
    induction vs generalizing acc with
    | nil => simp
    | cons v vs ih =>
        simp only [List.foldl_cons, List.length_cons, ih]
        rw [addVote_counts]
        omega
  have hfin := h Tally.zero votes
  simpa [tally, Tally.zero] using hfin

/-- Winner determination (consensus.ts ll. 128–141): strict plurality of
    weighted sums; every tie collapses to NEUTRAL. -/
def winner (t : Tally) : Signal :=
  if t.shortW < t.longW ∧ t.neutralW < t.longW then .long
  else if t.longW < t.shortW ∧ t.neutralW < t.shortW then .short
  else .neutral

theorem winner_eq_long {t : Tally} :
    winner t = .long ↔ t.shortW < t.longW ∧ t.neutralW < t.longW := by
  by_cases h1 : t.shortW < t.longW ∧ t.neutralW < t.longW
  · have hw : winner t = .long := by unfold winner; rw [if_pos h1]
    exact ⟨fun _ => h1, fun _ => hw⟩
  · have hw : winner t ≠ .long := by
      intro hc
      unfold winner at hc
      rw [if_neg h1] at hc
      by_cases h2 : t.longW < t.shortW ∧ t.neutralW < t.shortW
      · rw [if_pos h2] at hc; cases hc
      · rw [if_neg h2] at hc; cases hc
    exact ⟨fun h => absurd h hw, fun h => absurd h h1⟩

theorem winner_eq_short {t : Tally} :
    winner t = .short ↔ t.longW < t.shortW ∧ t.neutralW < t.shortW := by
  by_cases h2 : t.longW < t.shortW ∧ t.neutralW < t.shortW
  · by_cases h1 : t.shortW < t.longW ∧ t.neutralW < t.longW
    · exfalso
      have hcontra : False := by grind
      exact hcontra.elim
    · have hw : winner t = .short := by
        unfold winner; rw [if_neg h1, if_pos h2]
      exact ⟨fun _ => h2, fun _ => hw⟩
  · have hw : winner t ≠ .short := by
      intro hc
      unfold winner at hc
      by_cases h1 : t.shortW < t.longW ∧ t.neutralW < t.longW
      · rw [if_pos h1] at hc; cases hc
      · rw [if_neg h1, if_neg h2] at hc; cases hc
    exact ⟨fun h => absurd h hw, fun h => absurd h h2⟩

theorem winner_eq_neutral {t : Tally} :
    winner t = .neutral ↔
      ¬ (t.shortW < t.longW ∧ t.neutralW < t.longW) ∧
      ¬ (t.longW < t.shortW ∧ t.neutralW < t.shortW) := by
  by_cases h1 : t.shortW < t.longW ∧ t.neutralW < t.longW
  · have hw : winner t = .long := by unfold winner; rw [if_pos h1]
    constructor
    · intro h; rw [hw] at h; cases h
    · intro h; exact absurd h1 h.1
  · by_cases h2 : t.longW < t.shortW ∧ t.neutralW < t.shortW
    · have hw : winner t = .short := by
        unfold winner; rw [if_neg h1, if_pos h2]
      constructor
      · intro h; rw [hw] at h; cases h
      · intro h; exact absurd h2 h.2
    · have hw : winner t = .neutral := by
        unfold winner; rw [if_neg h1, if_neg h2]
      exact ⟨fun _ => ⟨h1, h2⟩, fun _ => hw⟩

def totalW (t : Tally) : Rat := t.longW + t.shortW + t.neutralW

/-- Branch confidence before the adversarial reduction
    (consensus.ts ll. 144–156). -/
def rawConfidence (t : Tally) : Rat :=
  if winner t = .neutral then
    if 0 < totalW t then t.neutralW / totalW t * 60 else 20
  else if 0 < totalW t then
    (if winner t = .long then t.longW - t.shortW else t.shortW - t.longW)
      / totalW t * 100
  else 20

/-- `balanceRatio` (consensus.ts ll. 159–162): count-based, not
    weight-based; 0 when there are no non-neutral votes. -/
def balanceRatio (t : Tally) : Rat :=
  let nn := t.longC + t.shortC
  if nn = 0 then 0
  else (if (t.shortC : Rat) ≤ t.longC then (t.longC : Rat) - t.shortC
        else (t.shortC : Rat) - t.longC) / (nn : Rat)

/-- Adversarial reduction factor (consensus.ts ll. 164–170):
    ratio < 0.2 with ≥ 4 non-neutral votes halves confidence;
    ratio < 0.35 with ≥ 3 scales by 0.7. -/
def advFactor (t : Tally) : Rat :=
  if balanceRatio t < 1 / 5 ∧ 4 ≤ t.longC + t.shortC then 1 / 2
  else if balanceRatio t < 7 / 20 ∧ 3 ≤ t.longC + t.shortC then 7 / 10
  else 1

theorem advFactor_halve {t : Tally}
    (h1 : balanceRatio t < 1 / 5) (h2 : 4 ≤ t.longC + t.shortC) :
    advFactor t = 1 / 2 := by
  unfold advFactor
  rw [if_pos ⟨h1, h2⟩]

theorem advFactor_scale {t : Tally}
    (h1 : balanceRatio t < 7 / 20) (h2 : 3 ≤ t.longC + t.shortC)
    (h3 : ¬ (balanceRatio t < 1 / 5 ∧ 4 ≤ t.longC + t.shortC)) :
    advFactor t = 7 / 10 := by
  unfold advFactor
  rw [if_neg h3, if_pos ⟨h1, h2⟩]

theorem advFactor_one {t : Tally}
    (h1 : ¬ (balanceRatio t < 1 / 5 ∧ 4 ≤ t.longC + t.shortC))
    (h2 : ¬ (balanceRatio t < 7 / 20 ∧ 3 ≤ t.longC + t.shortC)) :
    advFactor t = 1 := by
  unfold advFactor
  rw [if_neg h1, if_neg h2]

/-- Final confidence: raw * factor, clamped to [10, 90]
    (consensus.ts l. 168: `Math.max(10, Math.min(90, confidence))`). -/
def finalConfidence (t : Tally) : Rat :=
  max 10 (min 90 (rawConfidence t * advFactor t))

theorem confidence_bounds (t : Tally) :
    10 ≤ finalConfidence t ∧ finalConfidence t ≤ 90 := by
  unfold finalConfidence
  grind

/-- Empty vote list (no agent produced a vote): the pipeline still
    returns — and persists — a NEUTRAL signal at confidence 20.
    There is no empty-run guard anywhere in runSwarmAnalysis. -/
theorem consensus_empty_signal : winner (tally []) = .neutral := by decide

theorem consensus_empty_confidence : finalConfidence (tally []) = 20 := by
  have hw : winner (tally []) = .neutral := by decide
  have ht : totalW (tally []) = 0 := by
    simp only [totalW, tally, Tally.zero]
    grind
  have hnot : ¬ (0 : Rat) < totalW (tally []) := by
    rw [ht]; grind
  have hraw : rawConfidence (tally []) = 20 := by
    unfold rawConfidence
    rw [if_pos hw, if_neg hnot]
  have hfac : advFactor (tally []) = 1 :=
    advFactor_one (fun h => absurd h.2 (by decide)) (fun h => absurd h.2 (by decide))
  unfold finalConfidence
  rw [hraw, hfac]
  grind

/-- A concrete adversarial split (2 LONG vs 2 SHORT votes): the balance
    ratio is 0 < 0.2 with 4 non-neutral votes, so the halving branch of
    consensus.ts ll. 164–165 fires. -/
def fourVotes : List Vote :=
  [⟨"A", .long, 50⟩, ⟨"B", .long, 50⟩, ⟨"C", .short, 50⟩, ⟨"D", .short, 50⟩]

theorem fourVotes_ratio : balanceRatio (tally fourVotes) = 0 := by
  simp only [balanceRatio, tally, List.foldl_cons, List.foldl_nil, addVote,
    weightOf, fourVotes, Tally.zero]
  grind

theorem fourVotes_factor : advFactor (tally fourVotes) = 1 / 2 := by
  apply advFactor_halve
  · rw [fourVotes_ratio]; grind
  · simp only [tally, List.foldl_cons, List.foldl_nil, addVote, fourVotes,
      Tally.zero]
    omega

/-! ## Part B — is each participant counted once? -/

/-- Number of votes cast under agent name `a`. The tally counts list
    entries; this is the per-participant count. -/
def countOf (votes : List Vote) (a : String) : Nat :=
  (votes.filter (fun v => v.agent = a)).length

theorem countOf_cons (v : Vote) (vs : List Vote) (a : String) :
    countOf (v :: vs) a = (if v.agent = a then 1 else 0) + countOf vs a := by
  by_cases h : v.agent = a <;> simp [countOf, h] <;> omega

theorem countOf_eq_zero {vs : List Vote} {a : String}
    (h : a ∉ vs.map Vote.agent) : countOf vs a = 0 := by
  induction vs with
  | nil => rfl
  | cons v vs ih =>
      rw [countOf_cons]
      simp only [List.map_cons, List.mem_cons, not_or] at h
      have hne : v.agent ≠ a := fun he => h.1 he.symm
      rw [if_neg hne, Nat.zero_add]
      exact ih h.2

/-- Under a no-duplicate-types hypothesis, each participant is counted
    at most once. -/
theorem countOf_le_one {vs : List Vote}
    (h : (vs.map Vote.agent).Nodup) (a : String) : countOf vs a ≤ 1 := by
  induction vs with
  | nil => simp [countOf]
  | cons v vs ih =>
      rw [List.map_cons, List.nodup_cons] at h
      rw [countOf_cons]
      by_cases hcase : v.agent = a
      · subst hcase
        rw [if_pos rfl, countOf_eq_zero h.1]
        omega
      · rw [if_neg hcase]
        simp [ih h.2]

/-- The agent types produced by `runAllAgents` (agents.ts ll. 793–826):
    the 8 core agents in call order, then the SentimentAgent meta-vote. -/
def pipelineAgents : List String :=
  ["FundingAgent", "MomentumAgent", "VolatilityAgent", "VolumeAgent",
   "OrderbookAgent", "LiquidationAgent", "MeanReversionAgent",
   "TrendAgent", "SentimentAgent"]

theorem pipelineAgents_length : pipelineAgents.length = 9 := by decide
theorem pipelineAgents_nodup : pipelineAgents.Nodup := by decide

/-- Pipeline-level "counted once": any vote list whose agent types are
    exactly the pipeline's has each participant counted at most once.
    This holds because `runAllAgents` hard-codes one call per agent
    (agents.ts ll. 811–825) — it is a property of the caller, not of
    `computeConsensus`. -/
theorem pipeline_counted_once {vs : List Vote}
    (h : vs.map Vote.agent = pipelineAgents) (a : String) :
    countOf vs a ≤ 1 := by
  apply countOf_le_one
  rw [h]
  exact pipelineAgents_nodup

/-- COUNTEREXAMPLE — `computeConsensus` itself does not count each
    participant once. One FundingAgent LONG vote at confidence 100
    (scaled weight 13/10) loses to one LiquidationAgent SHORT vote
    (7/5). Listing the *same* FundingAgent vote twice flips the
    consensus to LONG and counts the participant twice. The function
    never deduplicates; `lastSignals` on the stigmergy board silently
    overwrites, masking the duplication in the UI while the counts and
    weights double-count. -/
def fundingLong : Vote := ⟨"FundingAgent", .long, 100⟩
def liquidationShort : Vote := ⟨"LiquidationAgent", .short, 100⟩

theorem single_tally_weights :
    (tally [fundingLong, liquidationShort]).longW = 13 / 10 ∧
    (tally [fundingLong, liquidationShort]).shortW = 7 / 5 ∧
    (tally [fundingLong, liquidationShort]).neutralW = 0 := by
  refine ⟨?_, ?_, ?_⟩ <;>
    simp only [tally, List.foldl_cons, List.foldl_nil, addVote, weightOf,
      fundingLong, liquidationShort, Tally.zero] <;> grind

theorem dup_tally_weights :
    (tally [fundingLong, fundingLong, liquidationShort]).longW = 13 / 5 ∧
    (tally [fundingLong, fundingLong, liquidationShort]).shortW = 7 / 5 ∧
    (tally [fundingLong, fundingLong, liquidationShort]).neutralW = 0 := by
  refine ⟨?_, ?_, ?_⟩ <;>
    simp only [tally, List.foldl_cons, List.foldl_nil, addVote, weightOf,
      fundingLong, liquidationShort, Tally.zero] <;> grind

theorem single_winner_short :
    winner (tally [fundingLong, liquidationShort]) = .short := by
  rw [winner_eq_short]
  obtain ⟨h1, h2, h3⟩ := single_tally_weights
  exact ⟨by rw [h1, h2]; grind, by rw [h3, h2]; grind⟩

theorem dup_winner_long :
    winner (tally [fundingLong, fundingLong, liquidationShort]) = .long := by
  rw [winner_eq_long]
  obtain ⟨h1, h2, h3⟩ := dup_tally_weights
  exact ⟨by rw [h2, h1]; grind, by rw [h3, h1]; grind⟩

theorem dup_countOf : countOf [fundingLong, fundingLong, liquidationShort] "FundingAgent" = 2 := by
  decide

/-! ## Pipeline stages (src/lib/swarm/index.ts, runSwarmAnalysis ll. 142–213)

    The pipeline is straight-line code: fetch (l. 146) → previous board →
    agents (l. 164) → consensus (l. 167) → persist signal / agent states /
    snapshot (ll. 170–211). No stage is conditional and no stage gates
    persistence — there is no confidence floor, no CHP gate, and no
    empty-vote check between `computeConsensus` and the DB writes. -/

inductive Stage where
  | fetch | agents | consensus | persist
  deriving DecidableEq, Repr

def pipelineTrace : List Stage := [.fetch, .agents, .consensus, .persist]

theorem pipelineTrace_exact :
    pipelineTrace = [.fetch, .agents, .consensus, .persist] := rfl

theorem pipelineTrace_nodup : pipelineTrace.Nodup := by decide

theorem pipelineTrace_all_stages :
    Stage.fetch ∈ pipelineTrace ∧ Stage.agents ∈ pipelineTrace ∧
    Stage.consensus ∈ pipelineTrace ∧ Stage.persist ∈ pipelineTrace := by
  decide

/-! ## Part C — the documented CHP machine (.chp/STATE_MACHINE.md)

    States (ll. 9–18) and transitions (ll. 27–36) as documented.
    The LOCKED transition carries a third-party CONFIRM token — the
    document's gating evidence. Any → HALT and Any → UNRESOLVED are the
    document's two escape hatches; they target only HALT / UNRESOLVED,
    so they cannot manufacture a LOCKED or CONVERGED state.
    REFRAME_REQUIRED's entry is specified only in the thresholds
    section (l. 42, foundation < 70), not the transition list — the
    model includes EXPLORING → REFRAME_REQUIRED and NOTES.md flags
    the ambiguity. -/

inductive CHPState where
  | exploring | provisional | provisionalLock | locked | converged
  | unresolved | requiresHuman | reframeRequired | halt
  deriving DecidableEq, Repr

/-- Third-party CONFIRM evidence for the lock transition. -/
inductive ConfirmToken where
  | confirm

inductive CHPStep : CHPState → CHPState → Prop where
  | explore_provisional : CHPStep .exploring .provisional
  | explore_human : CHPStep .exploring .requiresHuman
  | explore_reframe : CHPStep .exploring .reframeRequired
  | provisional_lock : CHPStep .provisional .provisionalLock
  | lock (tok : ConfirmToken) : CHPStep .provisionalLock .locked
  | reject_exploring : CHPStep .provisionalLock .exploring
  | locked_converged : CHPStep .locked .converged
  | any_halt (s : CHPState) : CHPStep s .halt
  | any_unresolved (s : CHPState) : CHPStep s .unresolved

/-- Reflexive-transitive closure of `CHPStep` (defined locally: core
    Lean ships no `ReflTransGen` — that is a Mathlib type). -/
inductive Reach : CHPState → CHPState → Prop where
  | refl {a : CHPState} : Reach a a
  | tail {a b c : CHPState} : Reach a b → CHPStep b c → Reach a c

/-- The only way into LOCKED is from PROVISIONAL_LOCK, via the
    CONFIRM-carrying transition. -/
theorem step_locked_iff {s : CHPState} :
    CHPStep s .locked ↔ s = .provisionalLock := by
  constructor
  · intro h
    cases h with
    | lock _ => rfl
  · intro h
    subst h
    exact CHPStep.lock .confirm

/-- The only way into CONVERGED is from LOCKED. -/
theorem step_converged {s : CHPState} (h : CHPStep s .converged) :
    s = .locked := by
  cases h with
  | locked_converged => rfl

/-- The only way into PROVISIONAL_LOCK is from PROVISIONAL. -/
theorem step_provisionalLock {s : CHPState} (h : CHPStep s .provisionalLock) :
    s = .provisional := by
  cases h with
  | provisional_lock => rfl

/-- Reaching LOCKED requires having reached PROVISIONAL_LOCK first —
    the documented machine cannot skip the validation stage. -/
theorem reach_locked_needs_provisionalLock {a : CHPState} :
    Reach a .locked → a = .locked ∨ Reach a .provisionalLock := by
  intro h
  have aux : ∀ {x y : CHPState}, Reach x y → y = .locked →
      x = .locked ∨ Reach x .provisionalLock := by
    intro x y hxy
    induction hxy with
    | refl => intro hy; exact Or.inl hy
    | tail hreach hstep _ih =>
        intro hy
        subst hy
        cases hstep with
        | lock _ => exact Or.inr hreach
  exact aux h rfl

/-- Reaching CONVERGED requires having reached LOCKED first. -/
theorem reach_converged_needs_locked {a : CHPState} :
    Reach a .converged → a = .converged ∨ Reach a .locked := by
  intro h
  have aux : ∀ {x y : CHPState}, Reach x y → y = .converged →
      x = .converged ∨ Reach x .locked := by
    intro x y hxy
    induction hxy with
    | refl => intro hy; exact Or.inl hy
    | tail hreach hstep _ih =>
        intro hy
        subst hy
        cases hstep with
        | locked_converged => exact Or.inr hreach
  exact aux h rfl

/-- Reaching PROVISIONAL_LOCK requires having reached PROVISIONAL. -/
theorem reach_provisionalLock_needs_provisional {a : CHPState} :
    Reach a .provisionalLock →
      a = .provisionalLock ∨ Reach a .provisional := by
  intro h
  have aux : ∀ {x y : CHPState}, Reach x y → y = .provisionalLock →
      x = .provisionalLock ∨ Reach x .provisional := by
    intro x y hxy
    induction hxy with
    | refl => intro hy; exact Or.inl hy
    | tail hreach hstep _ih =>
        intro hy
        subst hy
        cases hstep with
        | provisional_lock => exact Or.inr hreach
  exact aux h rfl

/-- No skipping in the documented machine: a run from EXPLORING that
    reaches CONVERGED has passed through PROVISIONAL, PROVISIONAL_LOCK
    and LOCKED — the full documented chain, third-party validation
    included (any step into LOCKED is, by `step_locked_iff`, the
    CONFIRM-carrying step out of PROVISIONAL_LOCK). -/
theorem no_skip_to_converged :
    Reach .exploring .converged →
      Reach .exploring .provisional ∧
      Reach .exploring .provisionalLock ∧
      Reach .exploring .locked := by
  intro h
  have hlocked : Reach .exploring .locked := by
    cases reach_converged_needs_locked h with
    | inl he => cases he
    | inr hr => exact hr
  have hplock : Reach .exploring .provisionalLock := by
    cases reach_locked_needs_provisionalLock hlocked with
    | inl he => cases he
    | inr hr => exact hr
  have hprov : Reach .exploring .provisional := by
    cases reach_provisionalLock_needs_provisional hplock with
    | inl he => cases he
    | inr hr => exact hr
  exact ⟨hprov, hplock, hlocked⟩
