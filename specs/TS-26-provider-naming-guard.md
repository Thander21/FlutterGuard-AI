---
spec_version: "openspec-1.0"
id: "FG-RIV-026"
title: "Riverpod providers must end in Provider"
status: "approved"
severity: "warning"
analysis: "parse-only"
ast_nodes:
  - "VariableDeclaration"
  - "InstanceCreationExpression"
  - "MethodInvocation[factory-shaped]"
invariant: "Every top-level variable or static field whose initializer is a Riverpod provider factory call — a factory-set head applied to a positional closure — MUST carry a name ending in `Provider`."
fp_limits:
  - "names already ending in Provider (including private _xProvider)"
  - "factory-shaped calls without a positional closure (provider-package create:/value: widgets)"
  - "non-provider initializers (plain values, aliases, tear-offs)"
  - "local variables and instance fields"
  - "Notifier subclass names (a class-naming gate, not this one)"
golden_vectors:
  failing: "benchmark/vectors/TC-26_prov.bad.dart"
  passing: "benchmark/vectors/TC-26_prov.good.dart"
auto_heal_strategy: "rename_to_provider_suffix"
---

# 1. Anti-Pattern Diagnosis

A provider without the suffix reads like a local value:
`ref.watch(counter)` hides an ambient subscription where
`ref.watch(counterProvider)` announces one. AI-generated
code routinely declares `final counter =
Provider((ref) => 0);`, and reviewers then miss the
subscription, grep-for-provider audits fail, and the bare
name collides with models and locals (`counter` the
provider vs `counter` the state class). The campodeforca
`ProviderNaming` gate (SYS-CAL-003 R2-5 tail T2) draws
the line at the suffix; this rule is that line, scoped
to ambient declarations (top-level variables and static
fields) so short-lived locals stay out. Severity is
warning: a misnamed provider never breaks a build, but
it fails the gate's readability bar — legacy trees
ratchet it through the baseline, not through silence.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
-final counter = Provider((ref) => 0);
+final counterProvider = Provider((ref) => 0);
```

# 3. Edge Cases and Non-Compliance

A provider factory call is an instance creation or
invocation whose head names a factory-set member —
`Provider`, `FutureProvider`, `StreamProvider`,
`StateProvider`, `NotifierProvider`,
`AsyncNotifierProvider`, `StateNotifierProvider`,
`ChangeNotifierProvider` (bare, prefixed, explicit
`new`; TS-02 factory set) — optionally followed by
`.autoDispose`/`.family` modifier segments, or any
`overrideWith` invocation, AND whose first positional
argument is a closure. The finding lands on the
declaration line and names the expected suffix.

- Bare `Provider((ref) => ...)` assigned to a
  suffixless top-level: MUST be flagged.
  [eval: TC-26.bad]
- `FutureProvider`/`StreamProvider`/`StateProvider`/
  `NotifierProvider`/`AsyncNotifierProvider`/
  `StateNotifierProvider`/`ChangeNotifierProvider`
  suffixless: MUST be flagged. [eval: TC-26.bad]
- Prefixed `r.Provider((ref) => ...)` suffixless:
  MUST be flagged (no import resolution needed —
  the positional closure is the discriminator).
  [eval: TC-26.bad]
- Modifier chains (`FutureProvider.autoDispose(...)`,
  `X.family(...)`) suffixless: MUST be flagged.
  [eval: TC-26.bad]
- Assigned `overrideWith` (`final x =
  foo.overrideWith((ref) => ...)`) suffixless: MUST
  be flagged. [eval: unit fixture]
- Suffixed names (`counterProvider`): MUST NOT be
  flagged. [eval: TC-26.good]
- Private suffixed (`_sessionProvider`): MUST NOT be
  flagged. [eval: TC-26.good]
- Lowercase (`fooprovider`) and plural
  (`fooProviders`) endings: MUST be flagged — the
  suffix is exactly `Provider`, case-sensitive.
  [eval: TC-26.bad]
- Factory-shaped calls with named-only arguments
  (`Provider(create: ...)`, `Provider.value(...)` —
  provider-package widgets): MUST NOT be flagged.
  [eval: TC-26.good]
- Non-provider initializers (literals, aliases like
  `final x = fooProvider;`, tear-offs): MUST NOT be
  flagged. [eval: TC-26.good]
- Static fields (`static final x =
  Provider(...)`) suffixless: MUST be flagged.
  [eval: TC-26.bad]
- Local variables holding provider factories: MUST
  NOT be flagged (ambient declarations only).
  [eval: TC-26.good]
- Instance fields holding provider factories: MUST
  NOT be flagged. [eval: unit fixture]
- Multi-declarator lists judge each declarator on
  its own initializer (`final a = Provider(...),
  b = 1;` flags only `a`). [eval: unit fixture]
- `overrideWithValue`/`overrideWithProvider`
  assignments: out of scope v0, NOT flagged.
  [unevaluated]
- `Notifier`/`AsyncNotifier` subclass names: out of
  scope (a class-naming gate, not this one), NOT
  flagged. [unevaluated]

`rename_to_provider_suffix` is model-owned per the
SYS-HEAL-001 closed fast-path list (a rename spans
every reference — multi-hunk, needs judgment); the
harness never attempts it as a fast-path patch.
[unevaluated]
