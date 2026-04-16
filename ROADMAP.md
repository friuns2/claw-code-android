# Clawable Coding Harness Roadmap

## Goal

Turn claw-code into the most **clawable** coding harness:
- no human-first terminal assumptions
- no fragile prompt injection timing
- no opaque session state
- no hidden plugin or MCP failures
- no manual babysitting for routine recovery

This roadmap assumes the primary users are **claws wired through hooks, plugins, sessions, and channel events**.

## Definition of "clawable"

A clawable harness is:
- deterministic to start
- machine-readable in state and failure modes
- recoverable without a human watching the terminal
- branch/test/worktree aware
- plugin/MCP lifecycle aware
- event-first, not log-first
- capable of autonomous next-step execution

## Current Pain Points

### 1. Session boot is fragile
- trust prompts can block TUI startup
- prompts can land in the shell instead of the coding agent
- "session exists" does not mean "session is ready"

### 2. Truth is split across layers
- tmux state
- clawhip event stream
- git/worktree state
- test state
- gateway/plugin/MCP runtime state

### 3. Events are too log-shaped
- claws currently infer too much from noisy text
- important states are not normalized into machine-readable events

### 4. Recovery loops are too manual
- restart worker
- accept trust prompt
- re-inject prompt
- detect stale branch
- retry failed startup
- classify infra vs code failures manually

### 5. Branch freshness is not enforced enough
- side branches can miss already-landed main fixes
- broad test failures can be stale-branch noise instead of real regressions

### 6. Plugin/MCP failures are under-classified
- startup failures, handshake failures, config errors, partial startup, and degraded mode are not exposed cleanly enough

### 7. Human UX still leaks into claw workflows
- too much depends on terminal/TUI behavior instead of explicit agent state transitions and control APIs

## Product Principles

1. **State machine first** — every worker has explicit lifecycle states.
2. **Events over scraped prose** — channel output should be derived from typed events.
3. **Recovery before escalation** — known failure modes should auto-heal once before asking for help.
4. **Branch freshness before blame** — detect stale branches before treating red tests as new regressions.
5. **Partial success is first-class** — e.g. MCP startup can succeed for some servers and fail for others, with structured degraded-mode reporting.
6. **Terminal is transport, not truth** — tmux/TUI may remain implementation details, but orchestration state must live above them.
7. **Policy is executable** — merge, retry, rebase, stale cleanup, and escalation rules should be machine-enforced.

## Roadmap

## Phase 1 — Reliable Worker Boot

### 1. Ready-handshake lifecycle for coding workers
Add explicit states:
- `spawning`
- `trust_required`
- `ready_for_prompt`
- `prompt_accepted`
- `running`
- `blocked`
- `finished`
- `failed`

Acceptance:
- prompts are never sent before `ready_for_prompt`
- trust prompt state is detectable and emitted
- shell misdelivery becomes detectable as a first-class failure state

### 1.5. First-prompt acceptance SLA
After `ready_for_prompt`, expose whether the first task was actually accepted within a bounded window instead of leaving claws in a silent limbo.

Emit typed signals for:
- `prompt.sent`
- `prompt.accepted`
- `prompt.acceptance_delayed`
- `prompt.acceptance_timeout`

Track at least:
- time from `ready_for_prompt` -> first prompt send
- time from first prompt send -> `prompt_accepted`
- whether acceptance required retry or recovery

Acceptance:
- clawhip can distinguish `worker is ready but idle` from `prompt was sent but not actually accepted`
- long silent gaps between ready-state and first-task execution become machine-visible
- recovery can trigger on acceptance timeout before humans start scraping panes

### 2. Trust prompt resolver
Add allowlisted auto-trust behavior for known repos/worktrees.

Acceptance:
- trusted repos auto-clear trust prompts
- events emitted for `trust_required` and `trust_resolved`
- non-allowlisted repos remain gated

### 3. Structured session control API
Provide machine control above tmux:
- create worker
- await ready
- send task
- fetch state
- fetch last error
- restart worker
- terminate worker

Acceptance:
- a claw can operate a coding worker without raw send-keys as the primary control plane

### 3.5. Boot preflight / doctor contract
Before spawning or prompting a worker, run a machine-readable preflight that reports whether the lane is actually safe to start.

Preflight should check and emit typed results for:
- repo/worktree existence and expected branch
- branch freshness vs base branch
- trust-gate likelihood / allowlist status
- required binaries and control sockets
- plugin discovery / allowlist / startup eligibility
- MCP config presence and server reachability expectations
- last-known failed boot reason, if any

Acceptance:
- claws can fail fast before launching a doomed worker
- a blocked start returns a short structured diagnosis instead of forcing pane-scrape triage
- clawhip can summarize `why this lane did not even start` without inferring from terminal noise

## Phase 2 — Event-Native Clawhip Integration

### 4. Canonical lane event schema
Define typed events such as:
- `lane.started`
- `lane.ready`
- `lane.prompt_misdelivery`
- `lane.blocked`
- `lane.red`
- `lane.green`
- `lane.commit.created`
- `lane.pr.opened`
- `lane.merge.ready`
- `lane.finished`
- `lane.failed`
- `branch.stale_against_main`

Acceptance:
- clawhip consumes typed lane events
- Discord summaries are rendered from structured events instead of pane scraping alone

### 4.5. Session event ordering + terminal-state reconciliation
When the same session emits contradictory lifecycle events (`idle`, `error`, `completed`, transport/server-down) in close succession, claw-code must expose a deterministic final truth instead of making downstream claws guess.

Required behavior:
- attach monotonic sequence / causal ordering metadata to session lifecycle events
- classify which events are terminal vs advisory
- reconcile duplicate or out-of-order terminal events into one canonical lane outcome
- distinguish `session terminal state unknown because transport died` from a real `completed`

Acceptance:
- clawhip can survive `completed -> idle -> error -> completed` noise without double-reporting or trusting the wrong final state
- server-down after a session event burst surfaces as a typed uncertainty state rather than silently rewriting history
- downstream automation has one canonical terminal outcome per lane/session

### 4.6. Event provenance / environment labeling
Every emitted event should say whether it came from a live lane, synthetic test, healthcheck, replay, or system transport layer so claws do not mistake test noise for production truth.

Required fields:
- event source kind (`live_lane`, `test`, `healthcheck`, `replay`, `transport`)
- environment / channel label
- emitter identity
- confidence / trust level for downstream automation

Acceptance:
- clawhip can ignore or down-rank test pings without heuristic text matching
- synthetic/system events do not contaminate lane status or trigger false follow-up automation
- event streams remain machine-trustworthy even when test traffic shares the same channel

### 4.7. Session identity completeness at creation time
A newly created session should not surface as `(untitled)` or `(unknown)` for fields that orchestrators need immediately.

Required behavior:
- emit stable title, workspace/worktree path, and lane/session purpose at creation time
- if any field is not yet known, emit an explicit typed placeholder reason rather than a bare unknown string
- reconcile later-enriched metadata back onto the same session identity without creating ambiguity

Acceptance:
- clawhip can route/triage a brand-new session without waiting for follow-up chatter
- `(untitled)` / `(unknown)` creation events no longer force humans or bots to guess scope
- session creation events are immediately actionable for monitoring and ownership decisions

### 4.8. Duplicate terminal-event suppression
When the same session emits repeated `completed`, `failed`, or other terminal notifications, claw-code should collapse duplicates before they trigger repeated downstream reactions.

Required behavior:
- attach a canonical terminal-event fingerprint per lane/session outcome
- suppress or coalesce repeated terminal notifications within a reconciliation window
- preserve raw event history for audit while exposing only one actionable terminal outcome downstream
- surface when a later duplicate materially differs from the original terminal payload

Acceptance:
- clawhip does not double-report or double-close based on repeated terminal notifications
- duplicate `completed` bursts become one actionable finish event, not repeated noise
- downstream automation stays idempotent even when the upstream emitter is chatty

### 4.9. Lane ownership / scope binding
Each session and lane event should declare who owns it and what workflow scope it belongs to, so unrelated external/system work does not pollute claw-code follow-up loops.

Required behavior:
- attach owner/assignee identity when known
- attach workflow scope (e.g. `claw-code-dogfood`, `external-git-maintenance`, `infra-health`, `manual-operator`)
- mark whether the current watcher is expected to act, observe only, or ignore
- preserve scope through session restarts, resumes, and late terminal events

Acceptance:
- clawhip can say `out-of-scope external session` without humans adding a prose disclaimer
- unrelated session churn does not trigger false claw-code follow-up or blocker reporting
- monitoring views can filter to `actionable for this claw` instead of mixing every session on the host

### 4.10. Nudge acknowledgment / dedupe contract
Periodic clawhip nudges should carry enough state for claws to know whether the current prompt is new work, a retry, or an already-acknowledged heartbeat.

Required behavior:
- attach nudge id / cycle id and delivery timestamp
- expose whether the current claw has already acknowledged or responded for that cycle
- distinguish `new nudge`, `retry nudge`, and `stale duplicate`
- allow downstream summaries to bind a reported pinpoint back to the triggering nudge id

Acceptance:
- claws do not keep manufacturing fresh follow-ups just because the same periodic nudge reappeared
- clawhip can tell whether silence means `not yet handled` or `already acknowledged in this cycle`
- recurring dogfood prompts become idempotent and auditable across retries

### 4.11. Stable roadmap-id assignment for newly filed pinpoints
When a claw records a new pinpoint/follow-up, the roadmap surface should assign or expose a stable tracking id immediately instead of leaving the item as anonymous prose.

Required behavior:
- assign a canonical roadmap id at filing time
- expose that id in the structured event/report payload
- preserve the same id across later edits, reorderings, and summary compression
- distinguish `new roadmap filing` from `update to existing roadmap item`

Acceptance:
- channel updates can reference a newly filed pinpoint by stable id in the same turn
- downstream claws do not need heuristic text matching to figure out whether a follow-up is new or already tracked
- roadmap-driven dogfood loops stay auditable even as the document is edited repeatedly

### 4.12. Roadmap item lifecycle state contract
Each roadmap pinpoint should carry a machine-readable lifecycle state so claws do not keep rediscovering or re-reporting items that are already active, resolved, or superseded.

Required behavior:
- expose lifecycle state (`filed`, `acknowledged`, `in_progress`, `blocked`, `done`, `superseded`)
- attach last state-change timestamp
- allow a new report to declare whether it is a first filing, status update, or closure
- preserve lineage when one pinpoint supersedes or merges into another

Acceptance:
- clawhip can tell `new gap` from `existing gap still active` without prose interpretation
- completed or superseded items stop reappearing as if they were fresh discoveries
- roadmap-driven follow-up loops become stateful instead of repeatedly stateless

### 4.13. Multi-message report atomicity
A single dogfood/lane update should be representable as one structured report payload, even if the chat surface ends up rendering it across multiple messages.

Required behavior:
- assign one report id for the whole update
- bind `active_sessions`, `exact_pinpoint`, `concrete_delta`, and `blocker` fields to that same report id
- expose message-part ordering when the chat transport splits the report
- allow downstream consumers to reconstruct one canonical update without scraping adjacent chat messages heuristically

Acceptance:
- clawhip and other claws can parse one logical update even when Discord delivery fragments it into several posts
- partial/misordered message bursts do not scramble `pinpoint` vs `delta` vs `blocker`
- dogfood reports become machine-reliable summaries instead of fragile chat archaeology

### 4.14. Cross-claw pinpoint dedupe / merge contract
When multiple claws file near-identical pinpoints from the same underlying failure, the roadmap surface should merge or relate them instead of letting duplicate follow-ups accumulate as separate discoveries.

Required behavior:
- compute or expose a similarity/dedupe key for newly filed pinpoints
- allow a new filing to link to an existing roadmap item as `same_root_cause`, `related`, or `supersedes`
- preserve reporter-specific evidence while collapsing the canonical tracked issue
- surface when a later filing is genuinely distinct despite similar wording

Acceptance:
- two claws reporting the same gap do not automatically create two independent roadmap items
- roadmap growth reflects real new findings instead of duplicate observer churn
- downstream monitoring can see both the canonical item and the supporting duplicate evidence without losing auditability

### 4.15. Pinpoint evidence attachment contract
Each filed pinpoint should carry structured supporting evidence so later implementers do not have to reconstruct why the gap was believed to exist.

Required behavior:
- attach evidence references such as session ids, message ids, commits, logs, stack traces, or file paths
- label each attachment by evidence role (`repro`, `symptom`, `root_cause_hint`, `verification`)
- preserve bounded previews for human scanning while keeping a canonical reference for machines
- allow evidence to be added after filing without changing the pinpoint identity

Acceptance:
- roadmap items stay actionable after chat scrollback or session context is gone
- implementation lanes can start from structured evidence instead of rediscovering the original failure
- prioritization can weigh pinpoints by evidence quality, not just prose confidence

### 4.16. Pinpoint priority / severity contract
Each filed pinpoint should expose a machine-readable urgency/severity signal so claws can separate immediate execution blockers from lower-priority clawability hardening.

Required behavior:
- attach priority/severity fields (for example `p0`/`p1`/`p2` or `critical`/`high`/`medium`/`low`)
- distinguish user-facing breakage, operator-only friction, observability debt, and long-tail hardening
- allow priority to change as new evidence lands without changing the pinpoint identity
- surface why the priority was assigned (blast radius, reproducibility, automation breakage, merge risk)

Acceptance:
- clawhip can rank fresh pinpoints without relying on prose urgency vibes
- implementation queues can pull true blockers ahead of reporting-only niceties
- roadmap dogfood stays focused on the most damaging clawability gaps first

### 4.17. Pinpoint-to-implementation handoff contract
A filed pinpoint should be able to turn into an execution lane without a human re-translating the same context by hand.

Required behavior:
- expose a structured handoff packet containing objective, suspected scope, evidence refs, priority, and suggested verification
- mark whether the pinpoint is `implementation_ready`, `needs_repro`, or `needs_triage`
- preserve the link between the roadmap item and any spawned execution lane/worktree/PR
- allow later execution results to update the original pinpoint state instead of forking separate unlinked narratives

Acceptance:
- a claw can pick up a filed pinpoint and start implementation with minimal re-interpretation
- roadmap items stop being dead prose and become executable handoff units
- follow-up loops can see which pinpoints have already turned into real execution lanes

### 4.18. Report backpressure / repetitive-summary collapse
Periodic dogfood reporting should avoid re-broadcasting the full known gap inventory every cycle when only a small delta changed.

Required behavior:
- distinguish `new since last report` from `still active but unchanged`
- emit compact delta-first summaries with an optional expandable full state
- track per-channel/reporting cursor so repeated unchanged items collapse automatically
- preserve one canonical full snapshot elsewhere for audit/debug without flooding the live channel

Acceptance:
- new signal does not get buried under the same repeated backlog list every cycle
- claws and humans can scan the latest update for actual change instead of re-reading the whole inventory
- recurring dogfood loops become low-noise without losing auditability

### 4.19. No-change / no-op acknowledgment contract
When a dogfood cycle produces no new pinpoint, no new delta, and no new blocker, claws should be able to acknowledge that cycle explicitly without pretending a fresh finding exists.

Required behavior:
- expose a structured `no_change` / `noop` outcome for a reporting cycle
- bind that outcome to the triggering nudge/report id
- distinguish `checked and unchanged` from `not yet checked`
- preserve the last meaningful pinpoint/delta reference without re-filing it as new work

Acceptance:
- recurring nudges do not force synthetic novelty when the real answer is `nothing changed`
- clawhip can tell `handled, no delta` apart from silence or missed handling
- dogfood loops become honest and low-noise when the system is stable

### 4.20. Observation freshness / staleness-age contract
Every reported status, pinpoint, or blocker should carry an explicit observation timestamp/age so downstream claws can tell fresh state from stale carry-forward.

Required behavior:
- attach observed-at timestamp and derived age to active-session state, pinpoints, and blockers
- distinguish freshly observed facts from carried-forward prior-cycle state
- allow freshness TTLs so old observations degrade from `current` to `stale` automatically
- surface when a report contains mixed freshness windows across its fields

Acceptance:
- claws do not mistake a 2-hour-old observation for current truth just because it reappeared in the latest report
- stale carried-forward state is visible and can be down-ranked or revalidated
- dogfood summaries remain trustworthy even when some fields are unchanged across many cycles

### 4.21. Fact / hypothesis / confidence labeling
Dogfood reports should distinguish confirmed observations from inferred root-cause guesses so downstream claws do not treat speculation as settled truth.

Required behavior:
- label each reported claim as `observed_fact`, `inference`, `hypothesis`, or `recommendation`
- attach a confidence score or confidence bucket to non-fact claims
- preserve which evidence supports each claim
- allow a later report to promote a hypothesis into confirmed fact without changing the underlying pinpoint identity

Acceptance:
- claws can tell `we saw X happen` from `we think Y caused it`
- speculative root-cause text does not get mistaken for machine-trustworthy state
- dogfood summaries stay honest about uncertainty while remaining actionable

### 4.22. Negative-evidence / searched-and-not-found contract
When a dogfood cycle reports that something was not found (no active sessions, no new delta, no repro, no blocker), the report should also say what was checked so absence is machine-meaningful rather than empty prose.

Required behavior:
- attach the checked surfaces/sources for negative findings (sessions, logs, roadmap, state file, channel window, etc.)
- distinguish `not observed in checked scope` from `unknown / not checked`
- preserve the query/window used for the negative observation when relevant
- allow later reports to invalidate an earlier negative finding if the search scope was incomplete

Acceptance:
- `no blocker` and `no new delta` become auditable conclusions rather than unverifiable vibes
- downstream claws can tell whether absence means `looked and clean` or `did not inspect`
- stable dogfood periods stay trustworthy without overclaiming certainty

### 4.23. Field-level delta attribution
Even in delta-first reporting, claws still need to know exactly which structured fields changed between cycles instead of inferring change from prose.

Required behavior:
- emit field-level change markers for core report fields (`active_sessions`, `pinpoint`, `delta`, `blocker`, lifecycle state, priority, freshness)
- distinguish `changed`, `unchanged`, `cleared`, and `carried_forward`
- preserve previous value references or hashes when useful for machine comparison
- allow one report to contain both changed and unchanged fields without losing per-field status

Acceptance:
- downstream claws can tell precisely what changed this cycle without diffing entire message bodies
- delta-first summaries remain compact while still being machine-comparable
- recurring reports stop forcing text-level reparse just to answer `what actually changed?`

### 4.24. Report schema versioning / compatibility contract
As structured dogfood reports evolve, the reporting surface needs explicit schema versioning so downstream claws can parse new fields safely without silent breakage.

Required behavior:
- attach schema version to each structured report payload
- define additive vs breaking field changes
- expose compatibility guidance for consumers that only understand older schemas
- preserve a minimal stable core so basic parsing survives partial upgrades

Acceptance:
- downstream claws can reject, warn on, or gracefully degrade unknown schema versions instead of misparsing silently
- adding new reporting fields does not randomly break existing automation
- dogfood reporting can evolve quickly without losing machine trust

### 4.25. Consumer capability negotiation for structured reports
Schema versioning alone is not enough if different claws consume different subsets of the reporting surface. The producer should know what the consumer can actually understand.

Required behavior:
- let downstream consumers advertise supported schema versions and optional field families/capabilities
- allow producers to emit a reduced-compatible payload when a consumer cannot handle richer report fields
- surface when a report was downgraded for compatibility vs emitted in full fidelity
- preserve one canonical full-fidelity representation for audit/debug even when a downgraded view is delivered

Acceptance:
- claws with older parsers can still consume useful reports without silent field loss being mistaken for absence
- richer report evolution does not force every consumer to upgrade in lockstep
- reporting remains machine-trustworthy across mixed-version claw fleets

### 4.26. Self-describing report schema surface
Even with versioning and capability negotiation, downstream claws still need a machine-readable way to discover what fields and semantics a report version actually contains.

Required behavior:
- expose a machine-readable schema/field registry for structured report payloads
- document field meanings, enums, optionality, and deprecation status in a consumable format
- let consumers fetch the schema for a referenced report version/capability set
- preserve stable identifiers for fields so docs, code, and live payloads point at the same schema truth

Acceptance:
- new consumers can integrate without reverse-engineering example payloads from chat logs
- schema drift becomes detectable against a declared source of truth
- structured report evolution stays fast without turning every integration into brittle archaeology

### 4.27. Audience-specific report projection
The same canonical dogfood report should be projectable into different consumer views (clawhip, Jobdori, human operator) without each consumer re-summarizing the full payload from scratch.

Required behavior:
- preserve one canonical structured report payload
- support consumer-specific projections/views (for example `delta_brief`, `ops_audit`, `human_readable`, `roadmap_sync`)
- let consumers declare preferred projection shape and verbosity
- make the projection lineage explicit so a terse view still points back to the canonical report

Acceptance:
- Jobdori/Clawhip/humans do not keep rebroadcasting the same full inventory in slightly different prose
- each consumer gets the right level of detail without inventing its own lossy summary layer
- reporting noise drops while the underlying truth stays shared and auditable

### 4.28. Canonical report identity / content-hash anchor
Once multiple projections and summaries exist, the system needs a stable identity anchor proving they all came from the same underlying report state.

Required behavior:
- assign a canonical report id plus content hash/fingerprint to the full structured payload
- include projection-specific metadata without changing the canonical identity of unchanged underlying content
- surface when two projections differ because the source report changed vs because only the rendering changed
- allow downstream consumers to detect accidental duplicate sends of the exact same report payload

Acceptance:
- claws can verify that different audience views refer to the same underlying report truth
- duplicate projections of identical content do not look like new state changes
- report lineage remains auditable even as the same canonical payload is rendered many ways

### 4.29. Projection invalidation / stale-view cache contract
If the canonical report changes, previously emitted audience-specific projections must be identifiable as stale so downstream claws do not keep acting on an old rendered view.

Required behavior:
- bind each projection to the canonical report id + content hash/version it was derived from
- mark projections as superseded when the underlying canonical payload changes
- expose whether a consumer is viewing the latest compatible projection or a stale cached one
- allow cheap regeneration of projections without minting fake new report identities

Acceptance:
- claws do not mistake an old `delta_brief` view for current truth after the canonical report was updated
- projection caching reduces noise/compute without increasing stale-action risk
- audience-specific views stay safely linked to the freshness of the underlying report

### 4.30. Projection-time redaction / sensitivity labeling
As canonical reports accumulate richer evidence, projections need an explicit policy for what can be shown to which audience without losing machine trust.

Required behavior:
- label report fields/evidence with sensitivity classes (for example `public`, `internal`, `operator_only`, `secret`)
- let projections redact, summarize, or hash sensitive fields according to audience policy while preserving the canonical report intact
- expose when a projection omitted or transformed data for sensitivity reasons
- preserve enough stable identity/provenance that redacted projections can still be correlated with the canonical report

Acceptance:
- richer canonical reports do not force all audience views to leak the same detail level
- consumers can tell `field absent because redacted` from `field absent because nonexistent`
- audience-specific projections stay safe without turning into unverifiable black boxes

### 4.31. Redaction provenance / policy traceability
When a projection redacts or transforms data, downstream consumers should be able to tell which policy/rule caused it rather than treating redaction as unexplained disappearance.

Required behavior:
- attach redaction reason/policy id to transformed or omitted fields
- distinguish policy-based redaction from size truncation, compatibility downgrade, and source absence
- preserve auditable linkage from the projection back to the canonical field classification
- allow operators to review which projection policy version produced the visible output

Acceptance:
- claws can tell *why* a field was hidden, not just that it vanished
- redacted projections remain operationally debuggable instead of opaque
- sensitivity controls stay auditable as reporting/projection policy evolves

### 4.32. Deterministic projection / redaction reproducibility
Given the same canonical report, schema version, consumer capability set, and projection policy, the emitted projection should be reproducible byte-for-byte (or canonically equivalent) so audits and diffing do not drift on re-render.

Required behavior:
- make projection/redaction output deterministic for the same inputs
- surface which inputs participate in projection identity (schema version, capability set, policy version, canonical content hash)
- distinguish content changes from nondeterministic rendering noise
- allow canonical equivalence checks even when transport formatting differs

Acceptance:
- re-rendering the same report for the same audience does not create fake deltas
- audit/debug workflows can reproduce why a prior projection looked the way it did
- projection pipelines stay machine-trustworthy under repeated regeneration

### 4.33. Projection golden-fixture / regression lock
Once structured projections become deterministic, claw-code still needs regression fixtures that lock expected outputs so report rendering changes cannot slip in unnoticed.

Required behavior:
- maintain canonical fixture inputs covering core report shapes, redaction classes, and capability downgrades
- snapshot or equivalence-test expected projections for supported audience views
- make intentional rendering/schema changes update fixtures explicitly rather than drifting silently
- surface which fixture set/version validated a projection pipeline change

Acceptance:
- projection regressions get caught before downstream claws notice broken or drifting output
- deterministic rendering claims stay continuously verified, not assumed
- report/projection evolution remains fast without sacrificing machine-trustworthy stability

### 4.34. Downstream consumer conformance test contract
Producer-side fixture coverage is not enough if real downstream claws still parse or interpret the reporting contract incorrectly. The ecosystem needs a way to verify consumer behavior against the declared report schema/projection rules.

Required behavior:
- define conformance cases for consumers across schema versions, capability downgrades, redaction states, and no-op cycles
- provide a machine-runnable consumer test kit or fixture bundle
- distinguish parse success from semantic correctness (for example: correctly handling `redacted` vs `missing`, `stale` vs `current`)
- surface which consumer/version last passed the conformance suite

Acceptance:
- report-contract drift is caught at the producer/consumer boundary, not only inside the producer
- downstream claws can prove they understand the structured reporting surface they claim to support
- mixed claw fleets stay interoperable without relying on optimism or manual spot checks

### 4.35. Provisional-status dedupe / in-flight acknowledgment suppression
When a claw emits temporary status such as `working on it`, `please wait`, or `adding a roadmap gap`, repeated provisional notices should not flood the channel unless something materially changed.

Required behavior:
- fingerprint provisional/in-flight status updates separately from terminal or delta-bearing reports
- suppress repeated provisional messages with unchanged meaning inside a short reconciliation window
- allow a new provisional update through only when progress state, owner, blocker, or ETA meaningfully changes
- preserve raw repeats for audit/debug without exposing each one as a fresh channel event

Acceptance:
- monitoring feeds do not churn on duplicate `please wait` / `working on it` messages
- consumers can tell the difference between `still in progress, unchanged` and `new actionable update`
- in-flight acknowledgments remain useful without drowning out real state transitions

### 4.36. Provisional-status escalation timeout
If a provisional/in-flight status remains unchanged for too long, the system should stop treating it as harmless noise and promote it back into an actionable stale signal.

Required behavior:
- attach timeout/TTL policy to provisional states
- escalate prolonged unchanged provisional status into a typed stale/blocker signal
- distinguish `deduped because still fresh` from `deduped too long and now suspicious`
- surface which timeout policy triggered the escalation

Acceptance:
- `working on it` does not suppress visibility forever when real progress stalled
- consumers can trust provisional dedupe without losing long-stuck work
- low-noise monitoring still resurfaces stale in-flight states at the right time

### 4.37. Policy-blocked action handoff
When a requested action is disallowed by branch/merge/release policy (for example direct `main` push), the system should expose a structured refusal plus the next safe execution path instead of leaving only freeform prose.

Required behavior:
- classify policy-blocked requests with a typed reason (`main_push_forbidden`, `release_requires_owner`, etc.)
- attach the governing policy source and actor scope when available
- emit a safe fallback path (`create branch`, `open PR`, `request owner approval`, etc.)
- allow downstream claws/operators to distinguish `blocked by policy` from `blocked by technical failure`

Acceptance:
- policy refusals become machine-actionable instead of dead-end chat text
- claws can pivot directly to the safe alternative workflow without re-triaging the same request
- monitoring/reporting can separate governance blocks from actual product/runtime defects

### 4.38. Policy exception / owner-approval token contract
For actions that are normally blocked by policy but can be allowed with explicit owner approval, the approval path should be machine-readable instead of relying on ambiguous prose interpretation.

Required behavior:
- represent policy exceptions as typed approval grants or tokens scoped to action/repo/branch/time window
- bind the approval to the approving actor identity and policy being overridden
- distinguish `no approval`, `approval pending`, `approval granted`, and `approval expired/revoked`
- let downstream claws verify an approval artifact before executing the otherwise-blocked action

Acceptance:
- exceptional approvals stop depending on fuzzy chat interpretation
- claws can safely execute policy-exception flows without confusing them with ordinary blocked requests
- governance stays auditable even when owner-authorized exceptions occur

### 4.39. Approval-token replay / one-time-use enforcement
If policy-exception approvals become machine-readable tokens, they also need replay protection so one explicit exception cannot be silently reused beyond its intended scope.

Required behavior:
- support one-time-use or bounded-use approval grants where appropriate
- record token consumption against the exact action/repo/branch/commit scope it authorized
- reject replay, scope expansion, or post-expiry reuse with typed policy errors
- surface whether an approval was unused, consumed, partially consumed, expired, or revoked

Acceptance:
- one owner-approved exception cannot quietly authorize repeated or broader dangerous actions
- claws can distinguish `valid approval present` from `approval already spent`
- governance exceptions remain auditable and non-replayable under automation

### 4.40. Approval-token delegation / execution chain traceability
If one actor approves an exception and another claw/bot/session executes it, the system should preserve the delegation chain so policy exceptions remain attributable end-to-end.

Required behavior:
- record approver identity, requesting actor, executing actor, and any intermediate relay/orchestrator hop
- preserve the delegation chain on approval verification and token consumption events
- distinguish direct self-use from delegated execution
- surface when execution occurs through an unexpected or unauthorized delegate

Acceptance:
- policy-exception execution stays attributable even across bot/session hops
- audits can answer `who approved`, `who requested`, and `who actually used it`
- delegated exception flows remain governable instead of collapsing into generic bot activity

### 4.41. Token-optimization / repo-scope guidance contract
New users hit token burn and context bloat immediately, but the product surface does not clearly explain how repo scope, ignored paths, and working-directory choice affect clawability.

Required behavior:
- explicitly document whether `.clawignore` / `.claudeignore` / `.gitignore` are honored, and how
- surface a simple recommendation to start from the smallest useful subdirectory instead of the whole monorepo when possible
- provide first-run guidance for excluding heavy/generated directories (`node_modules`, `dist`, `build`, `.next`, coverage, logs, dumps, generated reports`)
- make token-saving repo-scope guidance visible in onboarding/help rather than buried in external chat advice

Acceptance:
- new users can answer `how do I stop dragging junk into context?` from product docs/help alone
- first-run confusion about ignore files and repo scope drops sharply
- clawability improves before users burn tokens on obviously-avoidable junk

### 4.42. Workspace-scope weight preview / token-risk preflight
Before a user starts a session in a repo, claw-code should surface a lightweight estimate of how heavy the current workspace is and why it may be costly.

Required behavior:
- inspect the current working tree for high-risk token sinks (huge directories, generated artifacts, vendored deps, logs, dumps)
- summarize likely context-bloat sources before deep indexing or first large prompt flow
- recommend safer scope choices (e.g. narrower subdirectory, ignore patterns, cleanup targets)
- distinguish `workspace looks clean` from `workspace is likely to burn tokens fast`

Acceptance:
- users get an early warning before accidentally dogfooding the entire junkyard
- token-saving guidance becomes situational and concrete, not just generic docs
- onboarding catches avoidable repo-scope mistakes before they turn into cost/perf complaints

### 4.43. Safer-scope quick-apply action
After warning that the current workspace is too heavy, claw-code should offer a direct way to adopt the safer scope instead of leaving the user to manually reinterpret the advice.

Required behavior:
- turn scope recommendations into actionable choices (e.g. switch to subdirectory, generate ignore stub, exclude detected heavy paths)
- preview what would be included/excluded before applying the change
- preserve an easy path back to the original broader scope
- distinguish advisory suggestions from user-confirmed scope changes

Acceptance:
- users can go from `this workspace is too heavy` to `use this safer scope` in one step
- token-risk preflight becomes operational guidance, not just warning text
- first-run users stop getting stuck between diagnosis and manual cleanup

### 5. Failure taxonomy
Normalize failure classes:
- `prompt_delivery`
- `trust_gate`
- `branch_divergence`
- `compile`
- `test`
- `plugin_startup`
- `mcp_startup`
- `mcp_handshake`
- `gateway_routing`
- `tool_runtime`
- `infra`

Acceptance:
- blockers are machine-classified
- dashboards and retry policies can branch on failure type

### 5.5. Transport outage vs lane failure boundary
When the control server or transport goes down, claw-code should distinguish host-level outage from lane-local failure instead of letting all active lanes look broken in the same vague way.

Required behavior:
- emit typed transport outage events separate from lane failure events
- annotate impacted lanes with dependency status (`blocked_by_transport`) rather than rewriting them as ordinary lane errors
- preserve the last known good lane state before transport loss
- surface outage scope (`single session`, `single worker host`, `shared control server`)

Acceptance:
- clawhip can say `server down blocked 3 lanes` instead of pretending 3 independent lane failures happened
- recovery policies can restart transport separately from lane-local recovery recipes
- postmortems can separate infra blast radius from actual code-lane defects

### 6. Actionable summary compression
Collapse noisy event streams into:
- current phase
- last successful checkpoint
- current blocker
- recommended next recovery action

Acceptance:
- channel status updates stay short and machine-grounded
- claws stop inferring state from raw build spam

### 6.5. Blocked-state subphase contract
When a lane is `blocked`, also expose the exact subphase where progress stopped, rather than forcing claws to infer from logs.

Subphases should include at least:
- `blocked.trust_prompt`
- `blocked.prompt_delivery`
- `blocked.plugin_init`
- `blocked.mcp_handshake`
- `blocked.branch_freshness`
- `blocked.test_hang`
- `blocked.report_pending`

Acceptance:
- `lane.blocked` carries a stable subphase enum + short human summary
- clawhip can say "blocked at MCP handshake" or "blocked waiting for trust clear" without pane scraping
- retries can target the correct recovery recipe instead of treating all blocked states the same

## Phase 3 — Branch/Test Awareness and Auto-Recovery

### 7. Stale-branch detection before broad verification
Before broad test runs, compare current branch to `main` and detect if known fixes are missing.

Acceptance:
- emit `branch.stale_against_main`
- suggest or auto-run rebase/merge-forward according to policy
- avoid misclassifying stale-branch failures as new regressions

### 8. Recovery recipes for common failures
Encode known automatic recoveries for:
- trust prompt unresolved
- prompt delivered to shell
- stale branch
- compile red after cross-crate refactor
- MCP startup handshake failure
- partial plugin startup

Acceptance:
- one automatic recovery attempt occurs before escalation
- the attempted recovery is itself emitted as structured event data

### 8.5. Recovery attempt ledger
Expose machine-readable recovery progress so claws can see what automatic recovery has already tried, what is still running, and why escalation happened.

Ledger should include at least:
- recovery recipe id
- attempt count
- current recovery state (`queued`, `running`, `succeeded`, `failed`, `exhausted`)
- started/finished timestamps
- last failure summary
- escalation reason when retries stop

Acceptance:
- clawhip can report `auto-recover tried prompt replay twice, then escalated` without log archaeology
- operators can distinguish `no recovery attempted` from `recovery already exhausted`
- repeated silent retry loops become visible and auditable

### 9. Green-ness contract
Workers should distinguish:
- targeted tests green
- package green
- workspace green
- merge-ready green

Acceptance:
- no more ambiguous "tests passed" messaging
- merge policy can require the correct green level for the lane type
- a single hung test must not mask other failures: enforce per-test
  timeouts in CI (`cargo test --workspace`) so a 6-minute hang in one
  crate cannot prevent downstream crates from running their suites
- when a CI job fails because of a hang, the worker must report it as
  `test.hung` rather than a generic failure, so triage doesn't conflate
  it with a normal `assertion failed`
- recorded pinpoint (2026-04-08): `be561bf` swapped the local
  byte-estimate preflight for a `count_tokens` round-trip and silently
  returned `Ok(())` on any error, so `send_message_blocks_oversized_*`
  hung for ~6 minutes per attempt; the resulting workspace job crash
  hid 6 *separate* pre-existing CLI regressions (compact flag
  discarded, piped stdin vs permission prompter, legacy session layout,
  help/prompt assertions, mock harness count) that only became
  diagnosable after `8c6dfe5` + `5851f2d` restored the fast-fail path

## Phase 4 — Claws-First Task Execution

### 10. Typed task packet format
Define a structured task packet with fields like:
- objective
- scope
- repo/worktree
- branch policy
- acceptance tests
- commit policy
- reporting contract
- escalation policy

Acceptance:
- claws can dispatch work without relying on long natural-language prompt blobs alone
- task packets can be logged, retried, and transformed safely

### 11. Policy engine for autonomous coding
Encode automation rules such as:
- if green + scoped diff + review passed -> merge to dev
- if stale branch -> merge-forward before broad tests
- if startup blocked -> recover once, then escalate
- if lane completed -> emit closeout and cleanup session

Acceptance:
- doctrine moves from chat instructions into executable rules

### 12. Claw-native dashboards / lane board
Expose a machine-readable board of:
- repos
- active claws
- worktrees
- branch freshness
- red/green state
- current blocker
- merge readiness
- last meaningful event

Acceptance:
- claws can query status directly
- human-facing views become a rendering layer, not the source of truth

### 12.5. Running-state liveness heartbeat
When a lane is marked `working` or otherwise in-progress, emit a lightweight liveness heartbeat so claws can tell quiet progress from silent stall.

Heartbeat should include at least:
- current phase/subphase
- seconds since last meaningful progress
- seconds since last heartbeat
- current active step label
- whether background work is expected

Acceptance:
- clawhip can distinguish `quiet but alive` from `working state went stale`
- stale detection stops depending on raw pane churn alone
- long-running compile/test/background steps stay machine-visible without log scraping

## Phase 5 — Plugin and MCP Lifecycle Maturity

### 13. First-class plugin/MCP lifecycle contract
Each plugin/MCP integration should expose:
- config validation contract
- startup healthcheck
- discovery result
- degraded-mode behavior
- shutdown/cleanup contract

Acceptance:
- partial-startup and per-server failures are reported structurally
- successful servers remain usable even when one server fails

### 14. MCP end-to-end lifecycle parity
Close gaps from:
- config load
- server registration
- spawn/connect
- initialize handshake
- tool/resource discovery
- invocation path
- error surfacing
- shutdown/cleanup

Acceptance:
- parity harness and runtime tests cover healthy and degraded startup cases
- broken servers are surfaced as structured failures, not opaque warnings

## Immediate Backlog (from current real pain)

Priority order: P0 = blocks CI/green state, P1 = blocks integration wiring, P2 = clawability hardening, P3 = swarm-efficiency improvements.

**P0 — Fix first (CI reliability)**
1. Isolate `render_diff_report` tests into tmpdir — **done**: `render_diff_report_for()` tests run in temp git repos instead of the live working tree, and targeted `cargo test -p rusty-claude-cli render_diff_report -- --nocapture` now stays green during branch/worktree activity
2. Expand GitHub CI from single-crate coverage to workspace-grade verification — **done**: `.github/workflows/rust-ci.yml` now runs `cargo test --workspace` plus fmt/clippy at the workspace level
3. Add release-grade binary workflow — **done**: `.github/workflows/release.yml` now builds tagged Rust release artifacts for the CLI
4. Add container-first test/run docs — **done**: `Containerfile` + `docs/container.md` document the canonical Docker/Podman workflow for build, bind-mount, and `cargo test --workspace` usage
5. Surface `doctor` / preflight diagnostics in onboarding docs and help — **done**: README + USAGE now put `claw doctor` / `/doctor` in the first-run path and point at the built-in preflight report
6. Automate branding/source-of-truth residue checks in CI — **done**: `.github/scripts/check_doc_source_of_truth.py` and the `doc-source-of-truth` CI job now block stale repo/org/invite residue in tracked docs and metadata
7. Eliminate warning spam from first-run help/build path — **done**: current `cargo run -q -p rusty-claude-cli -- --help` renders clean help output without a warning wall before the product surface
8. Promote `doctor` from slash-only to top-level CLI entrypoint — **done**: `claw doctor` is now a local shell entrypoint with regression coverage for direct help and health-report output
9. Make machine-readable status commands actually machine-readable — **done**: `claw --output-format json status` and `claw --output-format json sandbox` now emit structured JSON snapshots instead of prose tables
10. Unify legacy config/skill namespaces in user-facing output — **done**: skills/help JSON/text output now present `.claw` as the canonical namespace and collapse legacy roots behind `.claw`-shaped source ids/labels
11. Honor JSON output on inventory commands like `skills` and `mcp` — **done**: direct CLI inventory commands now honor `--output-format json` with structured payloads for both skills and MCP inventory
12. Audit `--output-format` contract across the whole CLI surface — **done**: direct CLI commands now honor deterministic JSON/text handling across help/version/status/sandbox/agents/mcp/skills/bootstrap-plan/system-prompt/init/doctor, with regression coverage in `output_format_contract.rs` and resumed `/status` JSON coverage

**P1 — Next (integration wiring, unblocks verification)**
1. Worker readiness handshake + trust resolution — **done**: `WorkerStatus` state machine with `Spawning` → `TrustRequired` → `ReadyForPrompt` → `PromptAccepted` → `Running` lifecycle, `trust_auto_resolve` + `trust_gate_cleared` gating
2. Add cross-module integration tests — **done**: 12 integration tests covering worker→recovery→policy, stale_branch→policy, green_contract→policy, reconciliation flows
3. Wire lane-completion emitter — **done**: `lane_completion` module with `detect_lane_completion()` auto-sets `LaneContext::completed` from session-finished + tests-green + push-complete → policy closeout
4. Wire `SummaryCompressor` into the lane event pipeline — **done**: `compress_summary_text()` feeds into `LaneEvent::Finished` detail field in `tools/src/lib.rs`

**P2 — Clawability hardening (original backlog)**
5. Worker readiness handshake + trust resolution — **done**: `WorkerStatus` state machine with `Spawning` → `TrustRequired` → `ReadyForPrompt` → `PromptAccepted` → `Running` lifecycle, `trust_auto_resolve` + `trust_gate_cleared` gating
6. Prompt misdelivery detection and recovery — **done**: `prompt_delivery_attempts` counter, `PromptMisdelivery` event detection, `auto_recover_prompt_misdelivery` + `replay_prompt` recovery arm
7. Canonical lane event schema in clawhip — **done**: `LaneEvent` enum with `Started/Blocked/Failed/Finished` variants, `LaneEvent::new()` typed constructor, `tools/src/lib.rs` integration
8. Failure taxonomy + blocker normalization — **done**: `WorkerFailureKind` enum (`TrustGate/PromptDelivery/Protocol/Provider`), `FailureScenario::from_worker_failure_kind()` bridge to recovery recipes
9. Stale-branch detection before workspace tests — **done**: `stale_branch.rs` module with freshness detection, behind/ahead metrics, policy integration
10. MCP structured degraded-startup reporting — **done**: `McpManager` degraded-startup reporting (+183 lines in `mcp_stdio.rs`), failed server classification (startup/handshake/config/partial), structured `failed_servers` + `recovery_recommendations` in tool output
11. Structured task packet format — **done**: `task_packet.rs` module with `TaskPacket` struct, validation, serialization, `TaskScope` resolution (workspace/module/single-file/custom), integrated into `tools/src/lib.rs`
12. Lane board / machine-readable status API — **done**: Lane completion hardening + `LaneContext::completed` auto-detection + MCP degraded reporting surface machine-readable state
13. **Session completion failure classification** — **done**: `WorkerFailureKind::Provider` + `observe_completion()` + recovery recipe bridge landed
14. **Config merge validation gap** — **done**: `config.rs` hook validation before deep-merge (+56 lines), malformed entries fail with source-path context instead of merged parse errors
15. **MCP manager discovery flaky test** — **done**: `manager_discovery_report_keeps_healthy_servers_when_one_server_fails` now runs as a normal workspace test again after repeated stable passes, so degraded-startup coverage is no longer hidden behind `#[ignore]`

16. **Commit provenance / worktree-aware push events** — **done**: `LaneCommitProvenance` now carries branch/worktree/canonical-commit/supersession metadata in lane events, and `dedupe_superseded_commit_events()` is applied before agent manifests are written so superseded commit events collapse to the latest canonical lineage
17. **Orphaned module integration audit** — **done**: `runtime` now keeps `session_control` and `trust_resolver` behind `#[cfg(test)]` until they are wired into a real non-test execution path, so normal builds no longer advertise dead clawability surface area.
18. **Context-window preflight gap** — **done**: provider request sizing now emits `context_window_blocked` before oversized requests leave the process, using a model-context registry instead of the old naive max-token heuristic.
19. **Subcommand help falls through into runtime/API path** — **done**: `claw doctor --help`, `claw status --help`, `claw sandbox --help`, and nested `mcp`/`skills` help are now intercepted locally without runtime/provider startup, with regression tests covering the direct CLI paths.
20. **Session state classification gap (working vs blocked vs finished vs truly stale)** — **done**: agent manifests now derive machine states such as `working`, `blocked_background_job`, `blocked_merge_conflict`, `degraded_mcp`, `interrupted_transport`, `finished_pending_report`, and `finished_cleanable`, and terminal-state persistence records commit provenance plus derived state so downstream monitoring can distinguish quiet progress from truly idle sessions.
21. **Resumed `/status` JSON parity gap** — **done**: resolved by the broader "Resumed local-command JSON parity gap" work tracked as #26 below. Re-verified on `main` HEAD `8dc6580` — `cargo test --release -p rusty-claude-cli resumed_status_command_emits_structured_json_when_requested` passes cleanly (1 passed, 0 failed), so resumed `/status --output-format json` now goes through the same structured renderer as the fresh CLI path. The original failure (`expected value at line 1 column 1` because resumed dispatch fell back to prose) no longer reproduces.
22. **Opaque failure surface for session/runtime crashes** — **done**: `safe_failure_class()` in `error.rs` classifies all API errors into 8 user-safe classes (`provider_auth`, `provider_internal`, `provider_retry_exhausted`, `provider_rate_limit`, `provider_transport`, `provider_error`, `context_window`, `runtime_io`). `format_user_visible_api_error` in `main.rs` attaches session ID + request trace ID to every user-visible error. Coverage in `opaque_provider_wrapper_surfaces_failure_class_session_and_trace` and 3 related tests.
23. **`doctor --output-format json` check-level structure gap** — **done**: `claw doctor --output-format json` now keeps the human-readable `message`/`report` while also emitting structured per-check diagnostics (`name`, `status`, `summary`, `details`, plus typed fields like workspace paths and sandbox fallback data), with regression coverage in `output_format_contract.rs`.
24. **Plugin lifecycle init/shutdown test flakes under workspace-parallel execution** — dogfooding surfaced that `build_runtime_runs_plugin_lifecycle_init_and_shutdown` could fail under `cargo test --workspace` while passing in isolation because sibling tests raced on tempdir-backed shell init script paths. **Done (re-verified 2026-04-11):** the current mainline helpers now isolate plugin lifecycle temp resources robustly enough that both `cargo test -p rusty-claude-cli build_runtime_runs_plugin_lifecycle_init_and_shutdown -- --nocapture` and `cargo test -p plugins plugin_registry_runs_initialize_and_shutdown_for_enabled_plugins -- --nocapture` pass, and the current `cargo test --workspace` run includes both tests as green. Treat the old filing as stale unless a new parallel-execution repro appears.
25. **`plugins::hooks::collects_and_runs_hooks_from_enabled_plugins` flaked on Linux CI, root cause was a stdin-write race not missing exec bit** — **done at `172a2ad` on 2026-04-08**. Dogfooding reproduced this four times on `main` (CI runs [24120271422](https://github.com/ultraworkers/claw-code/actions/runs/24120271422), [24120538408](https://github.com/ultraworkers/claw-code/actions/runs/24120538408), [24121392171](https://github.com/ultraworkers/claw-code/actions/runs/24121392171), [24121776826](https://github.com/ultraworkers/claw-code/actions/runs/24121776826)), escalating from first-attempt-flake to deterministic-red on the third push. Failure mode was `PostToolUse hook .../hooks/post.sh failed to start for "Read": Broken pipe (os error 32)` surfacing from `HookRunResult`. **Initial diagnosis was wrong.** The first theory (documented in earlier revisions of this entry and in the root-cause note on commit `79da4b8`) was that `write_hook_plugin` in `rust/crates/plugins/src/hooks.rs` was writing the generated `.sh` files without the execute bit and `Command::new(path).spawn()` was racing on fork/exec. An initial chmod-only fix at `4f7b674` was shipped against that theory and **still failed CI on run `24121776826`** with the same `Broken pipe` symptom, falsifying the chmod-only hypothesis. **Actual root cause.** `CommandWithStdin::output_with_stdin` in `rust/crates/plugins/src/hooks.rs` was unconditionally propagating `write_all` errors on the child's stdin pipe, including `std::io::ErrorKind::BrokenPipe`. The test hook scripts run in microseconds (`#!/bin/sh` + a single `printf`), so the child exits and closes its stdin before the parent finishes writing the ~200-byte JSON hook payload. On Linux the pipe raises `EPIPE` immediately; on macOS the pipe happens to buffer the small payload before the child exits, which is why the race only surfaced on ubuntu CI runners. The parent's `write_all` returned `Err(BrokenPipe)`, `output_with_stdin` returned that as a hook failure, and `run_command` classified the hook as "failed to start" even though the child had already run to completion and printed the expected message to stdout. **Fix (commit `172a2ad`, force-pushed over `4f7b674`).** Three parts: (1) **actual fix** — `output_with_stdin` now matches the `write_all` result and swallows `BrokenPipe` specifically, while propagating all other write errors unchanged; after a `BrokenPipe` swallow the code still calls `wait_with_output()` so stdout/stderr/exit code are still captured from the cleanly-exited child. (2) **hygiene hardening** — a new `make_executable` helper sets mode `0o755` on each generated `.sh` via `std::os::unix::fs::PermissionsExt` under `#[cfg(unix)]`. This is defense-in-depth for future non-sh hook runners, not the bug that was biting CI. (3) **regression guard** — new `generated_hook_scripts_are_executable` test under `#[cfg(unix)]` asserts each generated `.sh` file has at least one execute bit set (`mode & 0o111 != 0`) so future tweaks cannot silently regress the hygiene change. **Verification.** `cargo test --release -p plugins` 35 passing, fmt clean, clippy `-D warnings` clean; CI run [24121999385](https://github.com/ultraworkers/claw-code/actions/runs/24121999385) went green on first attempt on `main` for the hotfix commit. **Meta-lesson.** `Broken pipe (os error 32)` from a child-process spawn path is ambiguous between "could not exec" and "exec'd and exited before the parent finished writing stdin." The first theory cargo-culted the "could not exec" reading because the ROADMAP scaffolding anchored on the exec-bit guess; falsification came from empirical CI, not from code inspection. Record the pattern: when a pipe error surfaces on fork/exec, instrument what `wait_with_output()` actually reports on the child before attributing the failure to a permissions or issue.
26. **Resumed local-command JSON parity gap** — **done**: direct `claw --output-format json` already had structured renderers for `sandbox`, `mcp`, `skills`, `version`, and `init`, but resumed `claw --output-format json --resume <session> /…` paths still fell back to prose because resumed slash dispatch only emitted JSON for `/status`. Resumed `/sandbox`, `/mcp`, `/skills`, `/version`, and `/init` now reuse the same JSON envelopes as their direct CLI counterparts, with regression coverage in `rust/crates/rusty-claude-cli/tests/resume_slash_commands.rs` and `rust/crates/rusty-claude-cli/tests/output_format_contract.rs`.
27. **`dev/rust` `cargo test -p rusty-claude-cli` reads host `~/.claude/plugins/installed/` from real `$HOME` and fails parse-time on any half-installed user plugin** — dogfooding on 2026-04-08 (filed from gaebal-gajae's clawhip bullet at message `1491322807026454579` after the provider-matrix branch QA surfaced it) reproduced 11 deterministic failures on clean `dev/rust` HEAD of the form `panicked at crates/rusty-claude-cli/src/main.rs:3953:31: args should parse: "hook path \`/Users/yeongyu/.claude/plugins/installed/sample-hooks-bundled/./hooks/pre.sh\` does not exist; hook path \`...\post.sh\` does not exist"` covering `parses_prompt_subcommand`, `parses_permission_mode_flag`, `defaults_to_repl_when_no_args`, `parses_resume_flag_with_slash_command`, `parses_system_prompt_options`, `parses_bare_prompt_and_json_output_flag`, `rejects_unknown_allowed_tools`, `parses_resume_flag_with_multiple_slash_commands`, `resolves_model_aliases_in_args`, `parses_allowed_tools_flags_with_aliases_and_lists`, `parses_login_and_logout_subcommands`. **Same failures do NOT reproduce on `main`** (re-verified with `cargo test --release -p rusty-claude-cli` against `main` HEAD `79da4b8`, all 156 tests pass). **Root cause is two-layered.** First, on `dev/rust` `parse_args` eagerly walks user-installed plugin manifests under `~/.claude/plugins/installed/` and validates that every declared hook script exists on disk before returning a `CliAction`, so any half-installed plugin in the developer's real `$HOME` (in this case `~/.claude/plugins/installed/sample-hooks-bundled/` whose `.claude-plugin` manifest references `./hooks/pre.sh` and `./hooks/post.sh` but whose `hooks/` subdirectory was deleted) makes argv parsing itself fail. Second, the test harness on `dev/rust` does not redirect `$HOME` or `XDG_CONFIG_HOME` to a fixture for the duration of the test — there is no `env_lock`-style guard equivalent to the one `main` already uses (`grep -n env_lock rust/crates/rusty-claude-cli/src/main.rs` returns 0 hits on `dev/rust` and 30+ hits on `main`). Together those two gaps mean `dev/rust` `cargo test -p rusty-claude-cli` is non-deterministic on every clean clone whose owner happens to have any non-pristine plugin in `~/.claude/`. **Action (two parts).** (a) Backport the `env_lock`-based test isolation pattern from `main` into `dev/rust`'s `rusty-claude-cli` test module so each test runs against a temp `$HOME`/`XDG_CONFIG_HOME` and cannot read host plugin state. (b) Decouple `parse_args` from filesystem hook validation on `dev/rust` (the same decoupling already on `main`, where hook validation happens later in the lifecycle than argv parsing) so even outside tests a partially installed user plugin cannot break basic CLI invocation. **Branch scope.** This is a `dev/rust` catchup against `main`, not a `main` regression. Tracking it here so the dev/rust merge train picks it up before the next dev/rust release rather than rediscovering it in CI.
28. **Auth-provider truth: error copy fails real users at the env-var-vs-header layer** — dogfooded live on 2026-04-08 in #claw-code (Sisyphus Labs guild), two separate new users hit adjacent failure modes within minutes of each other that both trace back to the same root: the `MissingApiKey` / 401 error surface does not teach users how the auth inputs map to HTTP semantics, so a user who sets a "reasonable-looking" env var still hits a hard error with no signpost. **Case 1 (varleg, Norway).** Wanted to use OpenRouter via the OpenAI-compat path. Found a comparison table claiming "provider-agnostic (Claude, OpenAI, local models)" and assumed it Just Worked. Set `OPENAI_API_KEY` to an OpenRouter `sk-or-v1-...` key and a model name without an `openai/` prefix; claw's provider detection fell through to Anthropic first because `ANTHROPIC_API_KEY` was still in the environment. Unsetting `ANTHROPIC_API_KEY` got them `ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY is not set` instead of a useful hint that the OpenAI path was right there. Fix delivered live as a channel reply: use `main` branch (not `dev/rust`), export `OPENAI_BASE_URL=https://openrouter.ai/api/v1` alongside `OPENAI_API_KEY`, and prefix the model name with `openai/` so the prefix router wins over env-var presence. **Case 2 (stanley078852).** Had set `ANTHROPIC_AUTH_TOKEN="sk-ant-..."` and was getting 401 `Invalid bearer token` from Anthropic. Root cause: `sk-ant-` keys are `x-api-key`-header keys, not bearer tokens. `ANTHROPIC_API_KEY` path in `anthropic.rs` sends the value as `x-api-key`; `ANTHROPIC_AUTH_TOKEN` path sends it as `Authorization: Bearer` (for OAuth access tokens from `claw login`). Setting an `sk-ant-` key in the wrong env var makes claw send it as `Bearer sk-ant-...` which Anthropic rejects at the edge with 401 before it ever reaches the completions endpoint. The error text propagated all the way to the user (`api returned 401 Unauthorized (authentication_error) ... Invalid bearer token`) with zero signal that the problem was env-var choice, not key validity. Fix delivered live as a channel reply: move the `sk-ant-...` key to `ANTHROPIC_API_KEY` and unset `ANTHROPIC_AUTH_TOKEN`. **Pattern.** Both cases are failures at the *auth-intent translation* layer: the user chose an env var that made syntactic sense to them (`OPENAI_API_KEY` for OpenAI, `ANTHROPIC_AUTH_TOKEN` for Anthropic auth) but the actual wire-format routing requires a more specific choice. The error messages surface the HTTP-layer symptom (401, missing-key) without bridging back to "which env var should you have used and why." **Action.** Three concrete improvements, scoped for a single `main`-side PR: (a) In `ApiError::MissingCredentials` Display, when the Anthropic path is the one being reported but `OPENAI_API_KEY`, `XAI_API_KEY`, or `DASHSCOPE_API_KEY` are present in the environment, extend the message with "— but I see `$OTHER_KEY` set; if you meant to use that provider, prefix your model name with `openai/`, `grok`, or `qwen/` respectively so prefix routing selects it." (b) In the 401-from-Anthropic error path in `anthropic.rs`, when the failing auth source is `BearerToken` AND the bearer token starts with `sk-ant-`, append "— looks like you put an `sk-ant-*` API key in `ANTHROPIC_AUTH_TOKEN`, which is the Bearer-header path. Move it to `ANTHROPIC_API_KEY` instead (that env var maps to `x-api-key`, which is the correct header for `sk-ant-*` keys)." Same treatment for OAuth access tokens landing in `ANTHROPIC_API_KEY` (symmetric mis-assignment). (c) In `rust/README.md` on `main` and the matrix section on `dev/rust`, add a short "Which env var goes where" paragraph mapping `sk-ant-*` → `ANTHROPIC_API_KEY` and OAuth access token → `ANTHROPIC_AUTH_TOKEN`, with the one-line explanation of `x-api-key` vs `Authorization: Bearer`. **Verification path.** Both improvements can be tested with unit tests against `ApiError::fmt` output (the prefix-routing hint) and with a targeted integration test that feeds an `sk-ant-*`-shaped token into `BearerToken` and asserts the fmt output surfaces the correction hint (no HTTP call needed). **Source.** Live users in #claw-code at `1491328554598924389` (varleg) and `1491329840706486376` (stanley078852) on 2026-04-08. **Partial landing (`ff1df4c`).** Action parts (a), (b), (c) shipped on `main`: `MissingCredentials` now carries an optional hint field and renders adjacent-provider signals, Anthropic 401 + `sk-ant-*` bearer gets a correction hint, USAGE.md has a "Which env var goes where" section. BUT the copy fix only helps users who fell through to the Anthropic auth path by accident — it does NOT fix the underlying routing bug where the CLI instantiates `AnthropicRuntimeClient` unconditionally and ignores prefix routing at the runtime-client layer. That deeper routing gap is tracked separately as #29 below and was filed within hours of #28 landing when live users still hit `missing Anthropic credentials` with `--model openai/gpt-4` and all `ANTHROPIC_*` env vars unset.
29. **CLI provider dispatch is hardcoded to Anthropic, ignoring prefix routing** — **done at `8dc6580` on 2026-04-08**. Changed `AnthropicRuntimeClient.client` from concrete `AnthropicClient` to `ApiProviderClient` (the api crate's `ProviderClient` enum), which dispatches to Anthropic / xAI / OpenAi at construction time based on `detect_provider_kind(&resolved_model)`. 1 file, +59 −7, all 182 rusty-claude-cli tests pass, CI green at run `24125825431`. Users can now run `claw --model openai/gpt-4.1-mini prompt "hello"` with only `OPENAI_API_KEY` set and it routes correctly. **Original filing below for the trace record.** Dogfooded live on 2026-04-08 within hours of ROADMAP #28 landing. Users in #claw-code (nicma at `1491342350960562277`, Jengro at `1491345009021030533`) followed the exact "use main, set OPENAI_API_KEY and OPENAI_BASE_URL, unset ANTHROPIC_*, prefix the model with `openai/`" checklist from the #28 error-copy improvements AND STILL hit `error: missing Anthropic credentials; export ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY before calling the Anthropic API`. **Reproduction on `main` HEAD `ff1df4c`:** `unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN; export OPENAI_API_KEY=sk-...; export OPENAI_BASE_URL=https://api.openai.com/v1; claw --model openai/gpt-4 prompt 'test'` → reproduces the error deterministically. **Root cause (traced).** `rust/crates/rusty-claude-cli/src/main.rs` at `build_runtime_with_plugin_state` (line ~6221) unconditionally builds `AnthropicRuntimeClient::new(session_id, model, ...)` without consulting `providers::detect_provider_kind(&model)`. `BuiltRuntime` at line ~2855 is statically typed as `ConversationRuntime<AnthropicRuntimeClient, CliToolExecutor>`, so even if the dispatch logic existed there would be nowhere to slot an alternative client. `providers/mod.rs::metadata_for_model` correctly identifies `openai/gpt-4` as `ProviderKind::OpenAi` at the metadata layer — the routing decision is *computed* correctly, it's just *never used* to pick a runtime client. The result is that the CLI is structurally single-provider (Anthropic only) even though the `api` crate's `openai_compat.rs`, `XAI_ENV_VARS`, `DASHSCOPE_ENV_VARS`, and `send_message_streaming` all exist and are exercised by unit tests inside the `api` crate. The provider matrix in `rust/README.md` is misleading because it describes the api-crate capabilities, not the CLI's actual dispatch behaviour. **Why #28 didn't catch this.** ROADMAP #28 focused on the `MissingCredentials` error *message* (adding hints when adjacent provider env vars are set, or when a bearer token starts with `sk-ant-*`). None of its tests exercised the `build_runtime` code path — they were all unit tests against `ApiError::fmt` output. The routing bug survives #28 because the `Display` improvements fire AFTER the hardcoded Anthropic client has already been constructed and failed. You need the CLI to dispatch to a different client in the first place for the new hints to even surface at the right moment. **Action (single focused commit).** (1) New `OpenAiCompatRuntimeClient` struct in `rust/crates/rusty-claude-cli/src/main.rs` mirroring `AnthropicRuntimeClient` but delegating to `openai_compat::send_message_streaming`. One client type handles OpenAI, xAI, DashScope, and any OpenAI-compat endpoint — they differ only in base URL and auth env var, both of which come from the `ProviderMetadata` returned by `metadata_for_model`. (2) New enum `DynamicApiClient { Anthropic(AnthropicRuntimeClient), OpenAiCompat(OpenAiCompatRuntimeClient) }` that implements `runtime::ApiClient` by matching on the variant and delegating. (3) Retype `BuiltRuntime` from `ConversationRuntime<AnthropicRuntimeClient, CliToolExecutor>` to `ConversationRuntime<DynamicApiClient, CliToolExecutor>`, update the Deref/DerefMut/new spots. (4) In `build_runtime_with_plugin_state`, call `detect_provider_kind(&model)` and construct either variant of `DynamicApiClient`. Prefix routing wins over env-var presence (that's the whole point). (5) Integration test using a mock OpenAI-compat server (reuse `mock_parity_harness` pattern from `crates/api/tests/`) that feeds `claw --model openai/gpt-4 prompt 'test'` with `OPENAI_BASE_URL` pointed at the mock and no `ANTHROPIC_*` env vars, asserts the request reaches the mock, and asserts the response round-trips as an `AssistantEvent`. (6) Unit test that `build_runtime_with_plugin_state` with `model="openai/gpt-4"` returns a `BuiltRuntime` whose inner client is the `DynamicApiClient::OpenAiCompat` variant. **Verification.** `cargo test --workspace`, `cargo fmt --all`, `cargo clippy --workspace`. **Source.** Live users nicma (`1491342350960562277`) and Jengro (`1491345009021030533`) in #claw-code on 2026-04-08, within hours of #28 landing.

41. **Phantom completions root cause: global session store has no per-worktree isolation** —

    **Root cause.** The session store under `~/.local/share/opencode` is global to the host. Every `opencode serve` instance — including the parallel lane workers spawned per worktree — reads and writes the same on-disk session directory. Sessions are keyed only by id and timestamp, not by the workspace they were created in, so there is no structural barrier between a session created in worktree `/tmp/b4-phantom-diag` and one created in `/tmp/b4-omc-flat`. Whichever serve instance picks up a given session id can drive it from whatever CWD that serve happens to be running in.

    **Impact.** Parallel lanes silently cross wires. A lane reports a clean run — file edits, builds, tests — and the orchestrator marks the lane green, but the writes were applied against another worktree's CWD because a sibling `opencode serve` won the session race. The originating worktree shows no diff, the *other* worktree gains unexplained edits, and downstream consumers (clawhip lane events, PR pushes, merge gates) treat the empty originator as a successful no-op. These are the "phantom completions" we keep chasing: success messaging without any landed changes in the lane that claimed them, plus stray edits in unrelated lanes whose own runs never touched those files. Because the report path is happy, retries and recovery recipes never fire, so the lane silently wedges until a human notices the diff is empty.

    **Proposed fix.** Bind every session to its workspace root + branch at creation time and refuse to drive it from any other CWD.

    - At session creation, capture the canonical workspace root (resolved git worktree path) and the active branch and persist them on the session record.
    - On every load (`opencode serve`, slash-command resume, lane recovery), validate that the current process CWD matches the persisted workspace root before any tool with side effects (file_ops, bash, git) is allowed to run. Mismatches surface as a typed `WorkspaceMismatch` failure class instead of silently writing to the wrong tree.
    - Namespace the on-disk session path under the workspace fingerprint (e.g. `<session_store>/<workspace_hash>/<session_id>`) so two parallel `opencode serve` instances physically cannot collide on the same session id.
    - Forks inherit the parent's workspace root by default; an explicit re-bind is required to move a session to a new worktree, and that re-bind is itself recorded as a structured event so the orchestrator can audit cross-worktree handoffs.
    - Surface a `branch.workspace_mismatch` lane event so clawhip stops counting wrong-CWD writes as lane completions.

    **Status.** Done. Managed-session creation/list/latest/load/fork now route through the per-worktree `SessionStore` namespace in runtime + CLI paths, session loads/resumes reject wrong-workspace access with typed `SessionControlError::WorkspaceMismatch` details, `branch.workspace_mismatch` / `workspace_mismatch` are available on the lane-event surface, and same-workspace legacy flat sessions remain readable while mismatched legacy access is blocked. Focused runtime/CLI/tools coverage for the isolation path is green, and the current full workspace gates now pass: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace`.

## Deployment Architecture Gap (filed from dogfood 2026-04-08)

### WorkerState is in the runtime; /state is NOT in opencode serve

**Root cause discovered during batch 8 dogfood.**

`worker_boot.rs` has a solid `WorkerStatus` state machine (`Spawning → TrustRequired → ReadyForPrompt → Running → Finished/Failed`). It is exported from `runtime/src/lib.rs` as a public API. But claw-code is a **plugin** loaded inside the `opencode` binary — it cannot add HTTP routes to `opencode serve`. The HTTP server is 100% owned by the upstream opencode process (v1.3.15).

**Impact:** There is no way to `curl localhost:4710/state` and get back a JSON `WorkerStatus`. Any such endpoint would require either:
1. Upstreaming a `/state` route into opencode's HTTP server (requires a PR to sst/opencode), or
2. Writing a sidecar HTTP process that queries the `WorkerRegistry` in-process (possible but fragile), or
3. Writing `WorkerStatus` to a well-known file path (`.claw/worker-state.json`) that an external observer can poll.

**Recommended path:** Option 3 — emit `WorkerStatus` transitions to `.claw/worker-state.json` on every state change. This is purely within claw-code's plugin scope, requires no upstream changes, and gives clawhip a file it can poll to distinguish a truly stalled worker from a quiet-but-progressing one.

**Action item:** Wire `WorkerRegistry::transition()` to atomically write `.claw/worker-state.json` on every state transition. Add a `claw state` CLI subcommand that reads and prints this file. Add regression test.

**Prior session note:** A previous session summary claimed commit `0984cca` landed a `/state` HTTP endpoint via axum. This was incorrect — no such commit exists on main, axum is not a dependency, and the HTTP server is not ours. The actual work that exists: `worker_boot.rs` with `WorkerStatus` enum + `WorkerRegistry`, fully wired into `runtime/src/lib.rs` as public exports.

## Startup Friction Gap: No Default trusted_roots in Settings (filed 2026-04-08)

### Every lane starts with manual trust babysitting unless caller explicitly passes roots

**Root cause discovered during direct dogfood of WorkerCreate tool.**

`WorkerCreate` accepts a `trusted_roots: Vec<String>` parameter. If the caller omits it (or passes `[]`), every new worker immediately enters `TrustRequired` and stalls — requiring manual intervention to advance to `ReadyForPrompt`. There is no mechanism to configure a default allowlist in `settings.json` or `.claw/settings.json`.

**Impact:** Batch tooling (clawhip, lane orchestrators) must pass `trusted_roots` explicitly on every `WorkerCreate` call. If a batch script forgets the field, all workers in that batch stall silently at `trust_required`. This was the root cause of several "batch 8 lanes not advancing" incidents.

**Recommended fix:**
1. Add a `trusted_roots` field to `RuntimeConfig` (or a nested `[trust]` table), loaded via `ConfigLoader`.
2. In `WorkerRegistry::spawn_worker()`, merge config-level `trusted_roots` with any per-call overrides.
3. Default: empty list (safest). Users opt in by adding their repo paths to settings.
4. Update `config_validate` schema with the new field.

**Action item:** Wire `RuntimeConfig::trusted_roots()` → `WorkerRegistry::spawn_worker()` default. Cover with test: config with `trusted_roots = ["/tmp"]` → spawning worker in `/tmp/x` auto-resolves trust without caller passing the field.

## Observability Transport Decision (filed 2026-04-08)

### Canonical state surface: CLI/file-based. HTTP endpoint deferred.

**Decision:** `claw state` reading `.claw/worker-state.json` is the **blessed observability contract** for clawhip and downstream tooling. This is not a stepping-stone — it is the supported surface. Build against it.

**Rationale:**
- claw-code is a plugin running inside the opencode binary. It cannot add HTTP routes to `opencode serve` — that server belongs to upstream sst/opencode.
- The file-based surface is fully within plugin scope: `emit_state_file()` in `worker_boot.rs` writes atomically on every `WorkerStatus` transition.
- `claw state --output-format json` gives clawhip everything it needs: `status`, `is_ready`, `seconds_since_update`, `trust_gate_cleared`, `last_event`, `updated_at`.
- Polling a local file has lower latency and fewer failure modes than an HTTP round-trip to a sidecar.
- An HTTP state endpoint would require either (a) upstreaming a route to sst/opencode — a multi-week PR cycle with no guarantee of acceptance — or (b) a sidecar process that queries `WorkerRegistry` in-process, which is fragile and adds an extra failure domain.

**What downstream tooling (clawhip) should do:**
1. After `WorkerCreate`, poll `.claw/worker-state.json` (or run `claw state --output-format json`) in the worker's CWD at whatever interval makes sense (e.g. 5s).
2. Trust `seconds_since_update > 60` in `trust_required` status as the stall signal.
3. Call `WorkerResolveTrust` tool to unblock, or `WorkerRestart` to reset.

**HTTP endpoint tracking:** Not scheduled. If a concrete use case emerges that file polling cannot serve (e.g. remote workers over a network boundary), open a new issue to upstream a `/worker/state` route to sst/opencode at that time. Until then: file/CLI is canonical.

## Provider Routing: Model-Name Prefix Must Win Over Env-Var Presence (fixed 2026-04-08, `0530c50`)

### `openai/gpt-4.1-mini` was silently misrouted to Anthropic when ANTHROPIC_API_KEY was set

**Root cause:** `metadata_for_model` returned `None` for any model not matching `claude` or `grok` prefix.
`detect_provider_kind` then fell through to auth-sniffer order: first `has_auth_from_env_or_saved()` (Anthropic), then `OPENAI_API_KEY`, then `XAI_API_KEY`.

If `ANTHROPIC_API_KEY` was present in the environment (e.g. user has both Anthropic and OpenRouter configured), any unknown model — including explicitly namespaced ones like `openai/gpt-4.1-mini` — was silently routed to the Anthropic client, which then failed with `missing Anthropic credentials` or a confusing 402/auth error rather than routing to OpenAI-compatible.

**Fix:** Added explicit prefix checks in `metadata_for_model`:
- `openai/` prefix → `ProviderKind::OpenAi`
- `gpt-` prefix → `ProviderKind::OpenAi`

Model name prefix now wins unconditionally over env-var presence. Regression test locked in: `providers::tests::openai_namespaced_model_routes_to_openai_not_anthropic`.

**Lesson:** Auth-sniffer fallback order is fragile. Any new provider added in the future should be registered in `metadata_for_model` via a model-name prefix, not left to env-var order. This is the canonical extension point.

30. **DashScope model routing in ProviderClient dispatch uses wrong config** — **done at `adcea6b` on 2026-04-08**. `ProviderClient::from_model_with_anthropic_auth` dispatched all `ProviderKind::OpenAi` matches to `OpenAiCompatConfig::openai()` (reads `OPENAI_API_KEY`, points at `api.openai.com`). But DashScope models (`qwen-plus`, `qwen/qwen-max`) return `ProviderKind::OpenAi` because DashScope speaks the OpenAI wire format — they need `OpenAiCompatConfig::dashscope()` (reads `DASHSCOPE_API_KEY`, points at `dashscope.aliyuncs.com/compatible-mode/v1`). Fix: consult `metadata_for_model` in the `OpenAi` dispatch arm and pick `dashscope()` vs `openai()` based on `metadata.auth_env`. Adds regression test + `pub base_url()` accessor. 2 files, +94/−3. Authored by droid (Kimi K2.5 Turbo) via acpx, cleaned up by Jobdori.

31. **`code-on-disk → verified commit lands` depends on undocumented executor quirks** — **verified external/non-actionable on 2026-04-12:** current `main` has no repo-local implementation surface for `acpx`, `use-droid`, `run-acpx`, `commit-wrapper`, or the cited `spawn ENOENT` behavior outside `ROADMAP.md`; those failures live in the external droid/acpx executor-orchestrator path, not claw-code source in this repository. Treat this as an external tracking note instead of an in-repo Immediate Backlog item. **Original filing below.**

31. **`code-on-disk → verified commit lands` depends on undocumented executor quirks** — dogfooded 2026-04-08 during live fix session. Three hidden contracts tripped the "last mile" path when using droid via acpx in the claw-code workspace: **(a) hidden CWD contract** — droid's `terminal/create` rejects `cd /path && cargo build` compound commands with `spawn ENOENT`; callers must pass `--cwd` or split commands; **(b) hidden commit-message transport limit** — embedding a multi-line commit message in a single shell invocation hits `ENAMETOOLONG`; workaround is `git commit -F <file>` but the caller must know to write the file first; **(c) hidden workspace lint/edition contract** — `unsafe_code = "forbid"` workspace-wide with Rust 2021 edition makes `unsafe {}` wrappers incorrect for `set_var`/`remove_var`, but droid generates Rust 2024-style unsafe blocks without inspecting the workspace Cargo.toml or clippy config. Each of these required the orchestrator to learn the constraint by failing, then switching strategies. **Acceptance bar:** a fresh agent should be able to verify/commit/push a correct diff in this workspace without needing to know executor-specific shell trivia ahead of time. **Fix shape:** (1) `run-acpx.sh`-style wrapper that normalizes the commit idiom (always writes to temp file, sets `--cwd`, splits compound commands); (2) inject workspace constraints into the droid/acpx task preamble (edition, lint gates, known shell executor quirks) so the model doesn't have to discover them from failures; (3) or upstream a fix to the executor itself so `cd /path && cmd` chains work correctly.

32. **OpenAI-compatible provider/model-id passthrough is not fully literal** — **verified no-bug on 2026-04-09**: `resolve_model_alias()` only matches bare shorthand aliases (`opus`/`sonnet`/`haiku`) and passes everything else through unchanged, so `openai/gpt-4` reaches the dispatch layer unmodified. `strip_routing_prefix()` at `openai_compat.rs:732` then strips only recognised routing prefixes (`openai`, `xai`, `grok`, `qwen`) so the wire model is the bare backend id. No fix needed. **Original filing below.**

42. **Hook JSON failure opacity: invalid hook output does not surface the offending payload/context** — dogfooding on 2026-04-13 in the live `clawcode-human` lane repeatedly hit `PreToolUse/PostToolUse/Stop hook returned invalid ... JSON output` while the operator had no immediate visibility into which hook emitted malformed JSON, what raw stdout/stderr came back, or whether the failure was hook-formatting breakage vs prompt-misdelivery fallout. This turns a recoverable hook/schema bug into generic lane fog. **Impact.** Lanes look blocked/noisy, but the event surface is too lossy to classify whether the next action is fix the hook serializer, retry prompt delivery, or ignore a harmless hook-side warning. **Concrete delta landed now.** Recorded as an Immediate Backlog item so the failure is tracked explicitly instead of disappearing into channel scrollback. **Recommended fix shape:** when hook JSON parse fails, emit a typed hook failure event carrying hook phase/name, command/path, exit status, and a redacted raw stdout/stderr preview (bounded + safe), plus a machine class like `hook_invalid_json`. Add regression coverage for malformed-but-nonempty hook output so the surfaced error includes the preview instead of only `invalid ... JSON output`.

32. **OpenAI-compatible provider/model-id passthrough is not fully literal** — dogfooded 2026-04-08 via live user in #claw-code who confirmed the exact backend model id works outside claw but fails through claw for an OpenAI-compatible endpoint. The gap: `openai/` prefix is correctly used for **transport selection** (pick the OpenAI-compat client) but the **wire model id** — the string placed in `"model": "..."` in the JSON request body — may not be the literal backend model string the user supplied. Two candidate failure modes: **(a)** `resolve_model_alias()` is called on the model string before it reaches the wire — alias expansion designed for Anthropic/known models corrupts a user-supplied backend-specific id; **(b)** the `openai/` routing prefix may not be stripped before `build_chat_completion_request` packages the body, so backends receive `openai/gpt-4` instead of `gpt-4`. **Fix shape:** cleanly separate transport selection from wire model id. Transport selection uses the prefix; wire model id is the user-supplied string minus only the routing prefix — no alias expansion, no prefix leakage. **Trace path for next session:** (1) find where `resolve_model_alias()` is called relative to the OpenAI-compat dispatch path; (2) inspect what `build_chat_completion_request` puts in `"model"` for an `openai/some-backend-id` input. **Source:** live user in #claw-code 2026-04-08, confirmed exact model id works outside claw, fails through claw for OpenAI-compat backend.

33. **OpenAI `/responses` endpoint rejects claw's tool schema: `object schema missing properties` / `invalid_function_parameters`** — **done at `e7e0fd2` on 2026-04-09**. Added `normalize_object_schema()` in `openai_compat.rs` which recursively walks JSON Schema trees and injects `"properties": {}` and `"additionalProperties": false` on every object-type node (without overwriting existing values). Called from `openai_tool_definition()` so both `/chat/completions` and `/responses` receive strict-validator-safe schemas. 3 unit tests added. All api tests pass. **Original filing below.**
33. **OpenAI `/responses` endpoint rejects claw's tool schema: `object schema missing properties` / `invalid_function_parameters`** — dogfooded 2026-04-08 via live user in #claw-code. Repro: startup succeeds, provider routing succeeds (`Connected: gpt-5.4 via openai`), but request fails when claw sends tool/function schema to a `/responses`-compatible OpenAI backend. Backend rejects `StructuredOutput` with `object schema missing properties` and `invalid_function_parameters`. This is distinct from the `#32` model-id passthrough issue — routing and transport work correctly. The failure is at the schema validation layer: claw's tool schema is acceptable for `/chat/completions` but not strict enough for `/responses` endpoint validation. **Sharp next check:** emit what schema claw sends for `StructuredOutput` tool functions, compare against OpenAI `/responses` spec for strict JSON schema validation (required `properties` object, `additionalProperties: false`, etc). Likely fix: add missing `properties: {}` on object types, ensure `additionalProperties: false` is present on all object schemas in the function tool JSON. **Source:** live user in #claw-code 2026-04-08 with `gpt-5.4` on OpenAI-compat backend.

34. **`reasoning_effort` / `budget_tokens` not surfaced on OpenAI-compat path** — **done (verified 2026-04-11):** current `main` already carries the Rust-side OpenAI-compat parity fix. `MessageRequest` now includes `reasoning_effort: Option<String>` in `rust/crates/api/src/types.rs`, `build_chat_completion_request()` emits `"reasoning_effort"` in `rust/crates/api/src/providers/openai_compat.rs`, and the CLI threads `--reasoning-effort low|medium|high` through to the API client in `rust/crates/rusty-claude-cli/src/main.rs`. The OpenAI-side parity target here is `reasoning_effort`; Anthropic-only `budget_tokens` remains handled on the Anthropic path. Re-verified on current `origin/main` / HEAD `2d5f836`: `cargo test -p api reasoning_effort -- --nocapture` passes (2 passed), and `cargo test -p rusty-claude-cli reasoning_effort -- --nocapture` passes (2 passed). Historical proof: `e4c3871` added the request field + OpenAI-compatible payload serialization, `ca8950c2` wired the CLI end-to-end, and `f741a425` added CLI validation coverage. **Original filing below.**

34. **`reasoning_effort` / `budget_tokens` not surfaced on OpenAI-compat path** — dogfooded 2026-04-09. Users asking for "reasoning effort parity with opencode" are hitting a structural gap: `MessageRequest` in `rust/crates/api/src/types.rs` has no `reasoning_effort` or `budget_tokens` field, and `build_chat_completion_request` in `openai_compat.rs` does not inject either into the request body. This means passing `--thinking` or equivalent to an OpenAI-compat reasoning model (e.g. `o4-mini`, `deepseek-r1`, any model that accepts `reasoning_effort`) silently drops the field — the model runs without the requested effort level, and the user gets no warning. **Contrast with Anthropic path:** `anthropic.rs` already maps `thinking` config into `anthropic.thinking.budget_tokens` in the request body. **Fix shape:** (a) Add optional `reasoning_effort: Option<String>` field to `MessageRequest`; (b) In `build_chat_completion_request`, if `reasoning_effort` is `Some`, emit `"reasoning_effort": value` in the JSON body; (c) In the CLI, wire `--thinking low/medium/high` or equivalent to populate the field when the resolved provider is `ProviderKind::OpenAi`; (d) Add unit test asserting `reasoning_effort` appears in the request body when set. **Source:** live user questions in #claw-code 2026-04-08/09 (dan_theman369 asking for "same flow as opencode for reasoning effort"; gaebal-gajae confirmed gap at `1491453913100976339`). Companion gap to #33 on the OpenAI-compat path.

35. **OpenAI gpt-5.x requires max_completion_tokens not max_tokens** — **done (verified 2026-04-11):** current `main` already carries the Rust-side OpenAI-compat fix. `build_chat_completion_request()` in `rust/crates/api/src/providers/openai_compat.rs` switches the emitted key to `"max_completion_tokens"` whenever the wire model starts with `gpt-5`, while older models still use `"max_tokens"`. Regression test `gpt5_uses_max_completion_tokens_not_max_tokens()` proves `gpt-5.2` emits `max_completion_tokens` and omits `max_tokens`. Re-verified against current `origin/main` `d40929ca`: `cargo test -p api gpt5_uses_max_completion_tokens_not_max_tokens -- --nocapture` passes. Historical proof: `eb044f0a` landed the request-field switch plus regression test on 2026-04-09. Source: rklehm in #claw-code 2026-04-09.

36. **Custom/project skill invocation disconnected from skill discovery** — **done (verified 2026-04-11):** current `main` already routes bare-word skill input in the REPL through `resolve_skill_invocation()` instead of forwarding it to the model. `rust/crates/rusty-claude-cli/src/main.rs` now treats a leading bare token that matches a known skill name as `/skills <input>`, while `rust/crates/commands/src/lib.rs` validates the skill against discovered project/user skill roots and reports available-skill guidance on miss. Fresh regression coverage proves the known-skill dispatch path and the unknown/non-skill bypass. Historical proof: `8d0308ee` landed the REPL dispatch fix. Source: gaebal-gajae dogfood 2026-04-09.

37. **Claude subscription login path should be removed, not deprecated** -- dogfooded 2026-04-09. Official auth should be API key only (`ANTHROPIC_API_KEY`) or OAuth bearer token via `ANTHROPIC_AUTH_TOKEN`; the local `claw login` / `claw logout` subscription-style flow created legal/billing ambiguity and a misleading saved-OAuth fallback. **Done (verified 2026-04-11):** removed the direct `claw login` / `claw logout` CLI surface, removed `/login` and `/logout` from shared slash-command discovery, changed both CLI and provider startup auth resolution to ignore saved OAuth credentials, and updated auth diagnostics to point only at `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`. Verification: targeted `commands`, `api`, and `rusty-claude-cli` tests for removed login/logout guidance and ignored saved OAuth all pass, and `cargo check -p api -p commands -p rusty-claude-cli` passes. Source: gaebal-gajae policy decision 2026-04-09.

38. **Dead-session opacity: bot cannot self-detect compaction vs broken tool surface** -- dogfooded 2026-04-09. Jobdori session spent ~15h declaring itself "dead" in-channel while tools were actually returning correct results within each turn. Root cause: context compaction causes tool outputs to be summarised away between turns, making the bot interpret absence-of-remembered-output as tool failure. This is a distinct failure mode from ROADMAP #31 (executor quirks): the session is alive and tools are functional, but the agent cannot tell the difference between "my last tool call produced no output" (compaction) and "the tool is broken". **Done (verified 2026-04-11):** `ConversationRuntime::run_turn()` now runs a post-compaction session-health probe through `glob_search`, fails fast with a targeted recovery error if the tool surface is broken, and skips the probe for a freshly compacted empty session. Fresh regression coverage proves both the failure gate and the empty-session bypass. Source: Jobdori self-dogfood 2026-04-09; observed in #clawcode-building-in-public across multiple Clawhip nudge cycles.

39. **Several slash commands were registered but not implemented: /branch, /rewind, /ide, /tag, /output-style, /add-dir** — **done (verified 2026-04-12):** current `main` already hides those stub commands from the user-facing discovery surfaces that mattered for the original report. Shared help rendering excludes them via `render_slash_command_help_filtered(...)`, and REPL completions exclude them via `STUB_COMMANDS`. Fresh proof: `cargo test -p commands renders_help_from_shared_specs -- --nocapture`, `cargo test -p rusty-claude-cli shared_help_uses_resume_annotation_copy -- --nocapture`, and `cargo test -p rusty-claude-cli stub_commands_absent_from_repl_completions -- --nocapture` all pass on current `origin/main`. Source: mezz2301 in #claw-code 2026-04-09; pinpointed in main.rs:3728.

40. **Surface broken installed plugins before they become support ghosts** — community-support lane. Clawhip commit `ff6d3b7` on worktree `claw-code-community-support-plugin-list-load-failures` / branch `community-support/plugin-list-load-failures`. When an installed plugin has a broken manifest (missing hook scripts, parse errors, bad json), the plugin silently fails to load and the user sees nothing — no warning, no list entry, no hint. Related to ROADMAP #27 (host plugin path leaking into tests) but at the user-facing surface: the test gap and the UX gap are siblings of the same root. **Done (verified 2026-04-11):** `PluginManager::plugin_registry_report()` and `installed_plugin_registry_report()` now preserve valid plugins while collecting `PluginLoadFailure`s, and the command-layer renderer emits a `Warnings:` block for broken plugins instead of silently hiding them. Fresh proof: `cargo test -p plugins plugin_registry_report_collects_load_failures_without_dropping_valid_plugins -- --nocapture`, `cargo test -p plugins installed_plugin_registry_report_collects_load_failures_from_install_root -- --nocapture`, and a new `commands` regression covering `render_plugins_report_with_failures()` all pass on current main.

41. **Stop ambient plugin state from skewing CLI regression checks** — community-support lane. Clawhip commit `7d493a7` on worktree `claw-code-community-support-plugin-test-sealing` / branch `community-support/plugin-test-sealing`. Companion to #40: the test sealing gap is the CI/developer side of the same root — host `~/.claude/plugins/installed/` bleeds into CLI test runs, making regression checks non-deterministic on any machine with a non-pristine plugin install. Closely related to ROADMAP #27 (dev/rust `cargo test` reads host plugin state). **Done (verified 2026-04-11):** the plugins crate now carries dedicated test-isolation helpers in `rust/crates/plugins/src/test_isolation.rs`, and regression `claw_config_home_isolation_prevents_host_plugin_leakage()` proves `CLAW_CONFIG_HOME` isolation prevents host plugin state from leaking into installed-plugin discovery during tests.

42. **`--output-format json` errors emitted as prose, not JSON** — dogfooded 2026-04-09. When `claw --output-format json prompt` hits an API error, the error was printed as plain text (`error: api returned 401 ...`) to stderr instead of a JSON object. Any tool or CI step parsing claw's JSON output gets nothing parseable on failure — the error is invisible to the consumer. **Fix (`a...`):** detect `--output-format json` in `main()` at process exit and emit `{"type":"error","error":"<message>"}` to stderr instead of the prose format. Non-JSON path unchanged. **Done** in this nudge cycle.

43. **Hook ingress opacity: typed hook-health/delivery report missing** — **verified likely external tracking on 2026-04-12:** repo-local searches for `/hooks/health`, `/hooks/status`, and hook-ingress route code found no implementation surface outside `ROADMAP.md`, and the prior state-surface note below already records that the HTTP server is not owned by claw-code. Treat this as likely upstream/server-surface tracking rather than an immediate claw-code task. **Original filing below.**
43. **Hook ingress opacity: typed hook-health/delivery report missing** — dogfooded 2026-04-09 while wiring the agentika timer→hook→session bridge. Debugging hook delivery required manual HTTP probing and inferring state from raw status codes (404 = no route, 405 = route exists, 400 = body missing required field). No typed endpoint exists to report: route present/absent, accepted methods, mapping matched/not matched, target session resolved/not resolved, last delivery failure class. Fix shape: add `GET /hooks/health` (or `/hooks/status`) returning a structured JSON diagnostic — no auth exposure, just routing/matching/session state. Source: gaebal-gajae dogfood 2026-04-09.

44. **Broad-CWD guardrail is warning-only; needs policy-level enforcement** — dogfooded 2026-04-09. `5f6f453` added a stderr warning when claw starts from `$HOME` or filesystem root (live user kapcomunica scanned their whole machine). Warning is a mitigation, not a guardrail: the agent still proceeds with unbounded scope. Follow-up fix shape: (a) add `--allow-broad-cwd` flag to suppress the warning explicitly (for legitimate home-dir use cases); (b) in default interactive mode, prompt "You are running from your home directory — continue? [y/N]" and exit unless confirmed; (c) in `--output-format json` or piped mode, treat broad-CWD as a hard error (exit 1) with `{"type":"error","error":"broad CWD: running from home directory requires --allow-broad-cwd"}`. Source: kapcomunica in #claw-code 2026-04-09; gaebal-gajae ROADMAP note same cycle.

45. **`claw dump-manifests` fails with opaque "No such file or directory"** — dogfooded 2026-04-09. `claw dump-manifests` emits `error: failed to extract manifests: No such file or directory (os error 2)` with no indication of which file or directory is missing. **Partial fix at `47aa1a5`+1**: error message now includes `looked in: <path>` so the build-tree path is visible, what manifests are, or how to fix it. Fix shape: (a) surface the missing path in the error message; (b) add a pre-check that explains what manifests are and where they should be (e.g. `.claw/manifests/` or the plugins directory); (c) if the command is only valid after `claw init` or after installing plugins, say so explicitly. Source: Jobdori dogfood 2026-04-09.

45. **`claw dump-manifests` fails with opaque `No such file or directory`** — **done (verified 2026-04-12):** current `main` now accepts `claw dump-manifests --manifests-dir PATH`, pre-checks for the required upstream manifest files (`src/commands.ts`, `src/tools.ts`, `src/entrypoints/cli.tsx`), and replaces the opaque os error with guidance that points users to `CLAUDE_CODE_UPSTREAM` or `--manifests-dir`. Fresh proof: parser coverage for both flag forms, unit coverage for missing-manifest and explicit-path flows, and `output_format_contract` JSON coverage via the new flag all pass. **Original filing below.**
45. **`claw dump-manifests` fails with opaque `No such file or directory`** — **done (verified 2026-04-12):** current `main` now accepts `claw dump-manifests --manifests-dir PATH`, pre-checks for the required upstream manifest files (`src/commands.ts`, `src/tools.ts`, `src/entrypoints/cli.tsx`), and replaces the opaque os error with guidance that points users to `CLAUDE_CODE_UPSTREAM` or `--manifests-dir`. Fresh proof: parser coverage for both flag forms, unit coverage for missing-manifest and explicit-path flows, and `output_format_contract` JSON coverage via the new flag all pass. **Original filing below.**
46. **`/tokens`, `/cache`, `/stats` were dead spec — parse arms missing** — dogfooded 2026-04-09. All three had spec entries with `resume_supported: true` but no parse arms, producing the circular error "Unknown slash command: /tokens — Did you mean /tokens". Also `SlashCommand::Stats` existed but was unimplemented in both REPL and resume dispatch. **Done at `60ec2ae` 2026-04-09**: `"tokens" | "cache"` now alias to `SlashCommand::Stats`; `Stats` is wired in both REPL and resume path with full JSON output. Source: Jobdori dogfood.

47. **`/diff` fails with cryptic "unknown option 'cached'" outside a git repo; resume /diff used wrong CWD** — dogfooded 2026-04-09. `claw --resume <session> /diff` in a non-git directory produced `git diff --cached failed: error: unknown option 'cached'` because git falls back to `--no-index` mode outside a git tree. Also resume `/diff` used `session_path.parent()` (the `.claw/sessions/<id>/` dir) as CWD for the diff — never a git repo. **Done at `aef85f8` 2026-04-09**: `render_diff_report_for()` now checks `git rev-parse --is-inside-work-tree` first and returns a clear "no git repository" message; resume `/diff` uses `std::env::current_dir()`. Source: Jobdori dogfood.

48. **Piped stdin triggers REPL startup and banner instead of one-shot prompt** — dogfooded 2026-04-09. `echo "hello" | claw` started the interactive REPL, printed the ASCII banner, consumed the pipe without sending anything to the API, then exited. `parse_args` always returned `CliAction::Repl` when no args were given, never checking whether stdin was a pipe. **Done at `84b77ec` 2026-04-09**: when `rest.is_empty()` and stdin is not a terminal, read the pipe and dispatch as `CliAction::Prompt`. Empty pipe still falls through to REPL. Source: Jobdori dogfood.

49. **Resumed slash command errors emitted as prose in `--output-format json` mode** — dogfooded 2026-04-09. `claw --output-format json --resume <session> /commit` called `eprintln!()` and `exit(2)` directly, bypassing the JSON formatter. Both the slash-command parse-error path and the `run_resume_command` Err path now check `output_format` and emit `{"type":"error","error":"...","command":"..."}`. **Done at `da42421` 2026-04-09**. Source: gaebal-gajae ROADMAP #26 track; Jobdori dogfood.

50. **PowerShell tool is registered as `danger-full-access` — workspace-aware reads still require escalation** — dogfooded 2026-04-10. User running `workspace-write` session mode (tanishq_devil in #claw-code) had to use `danger-full-access` even for simple in-workspace reads via PowerShell (e.g. `Get-Content`). Root cause traced by gaebal-gajae: `PowerShell` tool spec is registered with `required_permission: PermissionMode::DangerFullAccess` (same as the `bash` tool in `mvp_tool_specs`), not with per-command workspace-awareness. Bash shell and PowerShell execute arbitrary commands, so blanket promotion to `danger-full-access` is conservative — but it over-escalates read-only in-workspace operations. Fix shape: (a) add command-level heuristic analysis to the PowerShell executor (read-only commands like `Get-Content`, `Get-ChildItem`, `Test-Path` that target paths inside CWD → `WorkspaceWrite` required; everything else → `DangerFullAccess`); (b) mirror the same workspace-path check that the bash executor uses; (c) add tests covering the permission boundary for PowerShell read vs write vs network commands. Note: the `bash` tool in `mvp_tool_specs` is also `DangerFullAccess` and has the same gap — both should be fixed together. Source: tanishq_devil in #claw-code 2026-04-10; root cause identified by gaebal-gajae.

51. **Windows first-run onboarding missing: no explicit Rust + shell prerequisite branch** — dogfooded 2026-04-10 via #claw-code. User hit `bash: cargo: command not found`, `C:\...` vs `/c/...` path confusion in Git Bash, and misread `MINGW64` prompt as a broken MinGW install rather than normal Git Bash. Root cause: README/docs have no Windows-specific install path that says (1) install Rust first via rustup, (2) open Git Bash or WSL (not PowerShell or cmd), (3) use `/c/Users/...` style paths in bash, (4) then `cargo install claw-code`. Users can reach chat mode confusion before realizing claw was never installed. Fix shape: add a **Windows setup** section to README.md (or INSTALL.md) with explicit prerequisite steps, Git Bash vs WSL guidance, and a note that `MINGW64` in the prompt is expected and normal. Source: tanishq_devil in #claw-code 2026-04-10; traced by gaebal-gajae.

52. **`cargo install claw-code` false-positive install: deprecated stub silently succeeds** — dogfooded 2026-04-10 via #claw-code. User runs `cargo install claw-code`, install succeeds, Cargo places `claw-code-deprecated.exe`, user runs `claw` and gets `command not found`. The deprecated binary only prints `"claw-code has been renamed to agent-code"`. The success signal is false-positive: install appears to work but leaves the user with no working `claw` binary. Fix shape: (a) README must warn explicitly against `cargo install claw-code` with the hyphen (current note only warns about `clawcode` without hyphen); (b) if the deprecated crate is in our control, update its binary to print a clearer redirect message including `cargo install agent-code`; (c) ensure the Windows setup doc path mentions `agent-code` explicitly. Source: user in #claw-code 2026-04-10; traced by gaebal-gajae.

53. **`cargo install agent-code` produces `agent.exe`, not `agent-code.exe` — binary name mismatch in docs** — dogfooded 2026-04-10 via #claw-code. User follows the `claw-code` rename hint to run `cargo install agent-code`, install succeeds, but the installed binary is `agent.exe` (Unix: `agent`), not `agent-code` or `agent-code.exe`. User tries `agent-code --version`, gets `command not found`, concludes install is broken. The package name (`agent-code`), the crate name, and the installed binary name (`agent`) are all different. Fix shape: docs must show the full chain explicitly: `cargo install agent-code` → run via `agent` (Unix) / `agent.exe` (Windows). ROADMAP #52 note updated with corrected binary name. Source: user in #claw-code 2026-04-10; traced by gaebal-gajae.

54. **Circular "Did you mean /X?" error for spec-registered commands with no parse arm** — dogfooded 2026-04-10. 23 commands in the spec (shown in `/help` output) had no parse arm in `validate_slash_command_input`, so typing them produced `"Unknown slash command: /X — Did you mean /X?"`. The "Did you mean" suggestion pointed at the exact command the user just typed. Root cause: spec registration and parse-arm implementation were independent — a command could appear in help and completions without being parseable. **Done at `1e14d59` 2026-04-10**: added all 23 to STUB_COMMANDS and added pre-parse intercept in resume dispatch. Source: Jobdori dogfood.

55. **`/session list` unsupported in resume mode despite only needing directory read** — dogfooded 2026-04-10. `/session list` in `--output-format json --resume` mode returned `"unsupported resumed slash command"`. The command only reads the sessions directory — no live runtime needed. **Done at `8dcf103` 2026-04-10**: added `Session{action:"list"}` arm in `run_resume_command()`. Emits `{kind:session_list, sessions:[...ids], active:<id>}`. Partial progress on ROADMAP #21. Source: Jobdori dogfood.

56. **`--resume` with no command ignores `--output-format json`** — dogfooded 2026-04-10. `claw --output-format json --resume <session>` (no slash command) printed prose `"Restored session from <path> (N messages)."` to stdout, ignoring the JSON output format flag. **Done at `4f670e5` 2026-04-10**: empty-commands path now emits `{kind:restored, session_id, path, message_count}` in JSON mode. Source: Jobdori dogfood.

57. **Session load errors bypass `--output-format json` — prose error on corrupt JSONL** — dogfooded 2026-04-10. `claw --output-format json --resume <corrupt.jsonl> /status` printed bare prose `"failed to restore session: ..."` to stderr, not a JSON error object. Both the path-resolution and JSONL-load error paths ignored `output_format`. **Done at `cf129c8` 2026-04-10**: both paths now emit `{type:error, error:"failed to restore session: <detail>"}` in JSON mode. Source: Jobdori dogfood.

58. **Windows startup crash: `HOME is not set`** — user report 2026-04-10 in #claw-code (MaxDerVerpeilte). On Windows, `HOME` is often unset — `USERPROFILE` is the native equivalent. Four code paths only checked `HOME`: `config_home_dir()` (tools), `credentials_home_dir()` (runtime/oauth), `detect_broad_cwd()` (CLI), and skill lookup roots (tools). All crashed or silently skipped on stock Windows installs. **Done at `b95d330` 2026-04-10**: all four paths now fall back to `USERPROFILE` when `HOME` is absent. Error message updated to suggest `USERPROFILE` or `CLAW_CONFIG_HOME`. Source: MaxDerVerpeilte in #claw-code.

59. **Session metadata does not persist the model used** — dogfooded 2026-04-10. When resuming a session, `/status` reports `model: null` because the session JSONL stores no model field. A claw resuming a session cannot tell what model was originally used. The model is only known at runtime construction time via CLI flag or config. **Done at `0f34c66` 2026-04-10**: added `model: Option<String>` to Session struct, persisted in session_meta JSONL record, surfaced in resumed `/status`. Source: Jobdori dogfood.

60. **`glob_search` silently returns 0 results for brace expansion patterns** — user report 2026-04-10 in #claw-code (zero, Windows/Unity). Patterns like `Assets/**/*.{cs,uxml,uss}` returned 0 files because the `glob` crate (v0.3) does not support shell-style brace groups. The agent fell back to shell tools as a workaround. **Done at `3a6c9a5` 2026-04-10**: added `expand_braces()` pre-processor that expands brace groups before passing to `glob::glob()`. Handles nested braces. Results deduplicated via `HashSet`. 5 regression tests. Source: zero in #claw-code; traced by gaebal-gajae.

61. **`OPENAI_BASE_URL` ignored when model name has no recognized prefix** — user report 2026-04-10 in #claw-code (MaxDerVerpeilte, Ollama). User set `OPENAI_BASE_URL=http://127.0.0.1:11434/v1` with model `qwen2.5-coder:7b` but claw asked for Anthropic credentials. `detect_provider_kind()` checks model prefix first, then falls through to env-var presence — but `OPENAI_BASE_URL` was not in the cascade, so unrecognized model names always hit the Anthropic default. **Done at `1ecdb10` 2026-04-10**: `OPENAI_BASE_URL` + `OPENAI_API_KEY` now beats Anthropic env-check. `OPENAI_BASE_URL` alone (no key, e.g. Ollama) is last-resort before Anthropic default. Source: MaxDerVerpeilte in #claw-code; traced by gaebal-gajae.

62. **Worker state file surface not implemented** — **done (verified 2026-04-12):** current `main` already wires `emit_state_file(worker)` into the worker transition path in `rust/crates/runtime/src/worker_boot.rs`, atomically writes `.claw/worker-state.json`, and exposes the documented reader surface through `claw state` / `claw state --output-format json` in `rust/crates/rusty-claude-cli/src/main.rs`. Fresh proof exists in `runtime` regression `emit_state_file_writes_worker_status_on_transition`, the end-to-end `tools` regression `recovery_loop_state_file_reflects_transitions`, and direct CLI parsing coverage for `state` / `state --output-format json`. Source: Jobdori dogfood.

**Scope note (verified 2026-04-12):** ROADMAP #31, #43, and #63 currently appear to describe acpx/droid or upstream OMX/server orchestration behavior, not claw-code source already present in this repository. Repo-local searches for `acpx`, `use-droid`, `run-acpx`, `commit-wrapper`, `ultraclaw`, `/hooks/health`, and `/hooks/status` found no implementation hits outside `ROADMAP.md`, and the earlier state-surface note already records that the HTTP server is not owned by claw-code. With #45, #64-#69, and #75 now fixed, the remaining unresolved items in this section still look like external tracking notes rather than confirmed repo-local backlog; re-check if new repo-local evidence appears.

63. **Droid session completion semantics broken: code arrives after "status: completed"** — dogfooded 2026-04-12. Ultraclaw droid sessions (use-droid via acpx) report `session.status: completed` before file writes are fully flushed/synced to the working tree. Discovered +410 lines of "late-arriving" droid output that appeared after I had already assessed 8 sessions as "no code produced." This creates false-negative assessments and duplicate work. **Fix shape:** (a) droid agent should only report completion after explicit file-write confirmation (fsync or existence check); (b) or, claw-code should expose a `pending_writes` status that indicates "agent responded, disk flush pending"; (c) lane orchestrators should poll for file changes for N seconds after completion before final assessment. **Blocker:** none. Source: Jobdori ultraclaw dogfood 2026-04-12.

64a. **ACP/Zed editor integration entrypoint is too implicit** — **done (verified 2026-04-16):** `claw` now exposes a local `acp` discoverability surface (`claw acp`, `claw acp serve`, `claw --acp`, `claw -acp`) that answers the editor-first question directly without starting the runtime, and `claw --help` / `rust/README.md` now surface the ACP/Zed status in first-screen command/docs text. The current contract is explicit: claw-code does **not** ship an ACP/Zed daemon entrypoint yet; `claw acp serve` is only a status alias, while real ACP protocol support is tracked separately as #76. Fresh proof: parser coverage for `acp`/`acp serve`/flag aliases, help rendering coverage, and JSON output coverage for `claw --output-format json acp`.
Original filing (2026-04-13): user requested a `-acp` parameter to support ACP protocol integration in editor-first workflows such as Zed. The gap was a **discoverability and launch-contract problem**: the product surface did not make it obvious whether ACP was supported, how an editor should invoke claw-code, or whether a dedicated flag/mode existed at all.

64b. **Artifact provenance is post-hoc narration, not structured events** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now attaches structured `artifactProvenance` metadata to `lane.finished`, including `sourceLanes`, `roadmapIds`, `files`, `diffStat`, `verification`, and `commitSha`, while keeping the existing `lane.commit.created` provenance event intact. Regression coverage locks a successful completion payload that carries roadmap ids, file paths, diff stat, verification states, and commit sha without relying on prose re-parsing. **Original filing below.**

65. **Backlog-scanning team lanes emit opaque stops, not structured selection outcomes** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now recognizes backlog-scan selection summaries and records structured `selectionOutcome` metadata on `lane.finished`, including `chosenItems`, `skippedItems`, `action`, and optional `rationale`, while preserving existing non-selection and review-lane behavior. Regression coverage locks the structured backlog-scan payload alongside the earlier quality-floor and review-verdict paths. **Original filing below.**

66. **Completion-aware reminder shutdown missing** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now disables matching enabled cron reminders when the associated lane finishes successfully, and records the affected cron ids in `lane.finished.data.disabledCronIds`. Regression coverage locks the path where a ROADMAP-linked reminder is disabled on successful completion while leaving incomplete work untouched. **Original filing below.**

67. **Scoped review lanes do not emit structured verdicts** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now recognizes review-style `APPROVE`/`REJECT`/`BLOCKED` results and records structured `reviewVerdict`, `reviewTarget`, and `reviewRationale` metadata on the `lane.finished` event while preserving existing non-review lane behavior. Regression coverage locks both the normal completion path and a scoped review-lane completion payload. **Original filing below.**

68. **Internal reinjection/resume paths leak opaque control prose** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now recognizes `[OMX_TMUX_INJECT]`-style recovery control prose and records structured `recoveryOutcome` metadata on `lane.finished`, including `cause`, optional `targetLane`, and optional `preservedState`. Recovery-style summaries now normalize to a human-meaningful fallback instead of surfacing the raw internal marker as the primary lane result. Regression coverage locks both the tmux-idle reinjection path and the `Continue from current mode state` resume path. Source: gaebal-gajae / Jobdori dogfood 2026-04-12.

69. **Lane stop summaries have no minimum quality floor** — **done (verified 2026-04-12):** completed lane persistence in `rust/crates/tools/src/lib.rs` now normalizes vague/control-only stop summaries into a contextual fallback that includes the lane target and status, while preserving structured metadata about whether the quality floor fired (`qualityFloorApplied`, `rawSummary`, `reasons`, `wordCount`). Regression coverage locks both the pass-through path for good summaries and the fallback path for mushy summaries like `commit push everyting, keep sweeping $ralph`. **Original filing below.**

70. **Install-source ambiguity misleads real users** — **done (verified 2026-04-12):** repo-local Rust guidance now makes the source of truth explicit in `claw doctor` and `claw --help`, naming `ultraworkers/claw-code` as the canonical repo and warning that `cargo install claw-code` installs a deprecated stub rather than the `claw` binary. Regression coverage locks both the new doctor JSON check and the help-text warning. **Original filing below.**

71. **Wrong-task prompt receipt is not detected before execution** — **done (verified 2026-04-12):** worker boot prompt dispatch now accepts an optional structured `task_receipt` (`repo`, `task_kind`, `source_surface`, `expected_artifacts`, `objective_preview`) and treats mismatched visible prompt context as a `WrongTask` prompt-delivery failure before execution continues. The prompt-delivery payload now records `observed_prompt_preview` plus the expected receipt, and regression coverage locks both the existing shell/wrong-target paths and the new KakaoTalk-style wrong-task mismatch case. **Original filing below.**

72. **`latest` managed-session selection depends on filesystem mtime before semantic session recency** — **done (verified 2026-04-12):** managed-session summaries now carry `updated_at_ms`, `SessionStore::list_sessions()` sorts by semantic recency before filesystem mtime, and regression coverage locks the case where `latest` must prefer the newer session payload even when file mtimes point the other way. The CLI session-summary wrapper now stays in sync with the runtime field so `latest` resolution uses the same ordering signal everywhere. **Original filing below.**
73. **Session timestamps are not monotonic enough for latest-session ordering under tight loops** — **done (verified 2026-04-12):** runtime session timestamps now use a process-local monotonic millisecond source, so back-to-back saves still produce increasing `updated_at_ms` even when the wall clock does not advance. The temporary sleep hack was removed from the resume-latest regression, and fresh workspace verification stayed green with the semantic-recency ordering path from #72. **Original filing below.**

74. **Poisoned test locks cascade into unrelated Rust regressions** — **done (verified 2026-04-12):** test-only env/cwd lock acquisition in `rust/crates/tools/src/lib.rs`, `rust/crates/plugins/src/lib.rs`, `rust/crates/commands/src/lib.rs`, and `rust/crates/rusty-claude-cli/src/main.rs` now recovers poisoned mutexes via `PoisonError::into_inner`, and new regressions lock that behavior so one panic no longer causes later tests to fail just by touching the shared env/cwd locks. Source: Jobdori dogfood 2026-04-12.

75. **`claw init` leaves `.clawhip/` runtime artifacts unignored** — **done (verified 2026-04-12):** `rust/crates/rusty-claude-cli/src/init.rs` now treats `.clawhip/` as a first-class local artifact alongside `.claw/` paths, and regression coverage locks both the create and idempotent update paths so `claw init` adds the ignore entry exactly once. The repo `.gitignore` now also ignores `.clawhip/` for immediate dogfood relief, preventing repeated OMX team merge conflicts on `.clawhip/state/prompt-submit.json`. Source: Jobdori dogfood 2026-04-12.

76. **Real ACP/Zed daemon contract is still missing after the discoverability fix** — follow-up filed 2026-04-16. ROADMAP #64 made the current status explicit via `claw acp`, but editor-first users still cannot actually launch claw-code as an ACP/Zed daemon because there is no protocol-serving surface yet. **Fix shape:** add a real ACP entrypoint (for example `claw acp serve`) only when the underlying protocol/transport contract exists, then document the concrete editor wiring in `claw --help` and first-screen docs. **Acceptance bar:** an editor can launch claw-code for ACP/Zed from a documented, supported command rather than a status-only alias. **Blocker:** protocol/runtime work not yet implemented; current `acp serve` spelling is intentionally guidance-only.
