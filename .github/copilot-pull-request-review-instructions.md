# Copilot Pull Request Review Instructions

Guidance for Copilot when reviewing pull requests in `telometto/nix-config`.
These instructions complement [`copilot-instructions.md`](./copilot-instructions.md);
read that file first for repository conventions, module patterns, and
environment constraints.

## 1. What to ignore

Copilot **must not** flag or comment on purely cosmetic changes. These are
handled automatically by `treefmt` (`treefmt.nix`) and the `Auto Format`
workflow (`.github/workflows/auto-format.yml`), and commenting on them
creates noise without value. In particular, ignore:

- Whitespace, indentation, blank-line, or trailing-newline changes.
- Line-wrapping / line-length reflows that do not change semantics.
- Quote style changes (single vs. double quotes) in any language.
- Trailing commas, semicolons, or other purely syntactic punctuation
  preferences that the formatter owns.
- Reordering of imports, attributes, or list/set elements when the order
  is not semantically meaningful (e.g. attrset keys in Nix).
- Renaming of purely local bindings (`let`-bound names, lambda parameters)
  when the rename has no external effect and does not improve clarity in a
  material way.
- Comment rewording that does not change meaning.
- Markdown / YAML / JSON reformatting performed by `nix fmt`.
- Files under `.github/workflows/*.{yml,yaml}` being *not* reformatted —
  they are intentionally excluded from `yamlfmt` in `treefmt.nix`. Do not
  suggest reformatting them.

If the **only** change in a file or hunk is cosmetic, skip it entirely.
Do not leave "nit" comments for style. Do not suggest alternative
formatting. The formatter is the source of truth.

## 2. Read the conversation before commenting

Before leaving any review comment, Copilot **must**:

1. Read the PR description and linked issues.
1. Read **all existing review comments** on the PR, including resolved
   threads and outdated comments on earlier versions of the diff.
1. Read **replies** to those comments — especially author responses that
   explain, justify, or push back on a suggestion. If a prior reviewer
   already raised a point and the author answered it (or the point was
   resolved), do not raise the same point again unless there is new
   information in the latest push that invalidates the resolution.
1. Respect human reviewer decisions. If a human reviewer explicitly
   approved a pattern ("this is fine, we do it this way elsewhere"),
   treat that as settled.

When a prior comment thread is relevant to a new observation, reference
it explicitly instead of duplicating it ("addressed in thread above" /
"extending @user's point about X").

## 3. What to focus on

Spend review effort on things that actually matter for this repo:

### 3.1 Correctness & regressions

- Nix evaluation errors: unbound variables, wrong attribute paths,
  missing `lib.mkIf`, accidentally forcing evaluation of a disabled
  module, infinite recursion, `mkDefault` / `mkForce` misuse.
- Option typos under `sys.*` / `hm.*` that will silently do nothing.
- Breaking changes to option names, types, or defaults without a
  migration note.
- Host-level regressions (changes to `hosts/<hostname>/<hostname>.nix`
  that affect boot, networking, users, or storage).
- Changes to `flake.nix` that break the `mkHost` pattern used by
  `.github/workflows/validate-config.yml` (the workflow discovers hosts
  by grepping `^\s+\w+\s*=\s*mkHost` — preserve that spacing).
- Changes to `flake.lock` that are not produced by the lock-update
  workflows without explanation.

### 3.2 Module-system conventions

- A new file under `modules/` or `home/` must follow the option pattern:
  `options.sys.<...> = { enable = mkEnableOption …; … }; config = mkIf cfg.enable { … };`
  (or the `hm.<...>` equivalent). Flag modules that unconditionally apply
  config without an `enable` gate, unless the file is clearly a role
  bundle or a loader.
- Flag any file under `modules/` or `home/` added to an `imports = [ … ]`
  list — those trees are auto-loaded; explicit imports cause double-loads
  or break the loader contract.
- Flag files placed under `home/overrides/host/**` or
  `home/overrides/user/**` that do not match the `<host>.nix` or
  `<user>-<host>.nix` naming expected by `modules/core/home-users.nix`.
- Flag new options that leak outside the `sys.*` / `hm.*` namespaces
  without justification.

### 3.3 Security & secrets

- Any committed secret, private key, age identity, sops recipient, TLS
  key/cert, token, password, or anything from `vars/` or `nix-secrets/`
  is a **blocking** issue. Call it out prominently and recommend
  rotation.
- Changes that weaken Secure Boot (`lanzaboote`), sops wiring, firewall
  rules, SSH hardening, or `sys.security.*` defaults deserve a careful
  look.
- New services exposed to the network without authentication, TLS, or
  Tailscale scoping.
- New `nix-secrets` input URLs or anything that removes the SSH
  requirement on that private input — do not "helpfully" rewrite it to
  HTTPS or inline.

### 3.4 Documentation drift

- Public-facing option additions/removals under `sys.*` / `hm.*` should
  be reflected in `docs/reference-architecture.md`. Flag omissions.
- New hosts should be listed in `README.md` / relevant docs.
- Do not demand documentation for trivial internal changes.

### 3.5 CI & validation

- If a change touches `.nix`, `flake.lock`, or `treefmt.nix`, expect
  `Flake Check` and `Configuration Validation` to run. If a PR disables,
  skips, or works around those workflows, flag it.
- Do not request the author to run `nix flake check` locally — it
  requires SSH access to the private `nix-secrets` flake that most
  contributors and the Copilot sandbox do not have. CI is the source of
  truth.

## 4. Style & tone

- Be concise and specific. One issue per comment; group related points
  in a single thread rather than scattering nits.
- Prefer actionable suggestions (`suggestion` blocks when appropriate)
  over vague concerns.
- Distinguish severity: use clear prefixes such as **blocking**,
  **issue**, **question**, or **nit** only when a nit is unavoidable
  (per §1, most nits should simply be dropped).
- Avoid restating the diff. Assume the author can see their own changes.
- Do not generate long summaries of the PR; the author already knows
  what they wrote. A short top-level summary of findings (grouped by
  severity) is fine.
- Never suggest changes that contradict `treefmt.nix`, the auto-loader,
  or the environment constraints documented in `copilot-instructions.md`.

## 5. When in doubt, don't comment

If a change is:

- cosmetic only, **or**
- already discussed and resolved in an existing thread, **or**
- a matter of personal taste with no correctness / security /
  convention impact,

then stay silent. A quiet, high-signal review is more valuable than an
exhaustive one.
