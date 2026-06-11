# Devise 4.9.4 → 5.0.4 Upgrade

**Date:** 2026-06-11
**Branch:** `ba/devise-upgrade`

## Goal

Clear the two Devise CVEs currently in the `.bundler-audit.yml` ignore list by
upgrading the gem to the latest release. The erb and puma CVEs in the same
ignore list are out of scope and handled on a separate branch.

## Background

`bundle-audit` flags Devise 4.9.4 for two advisories:

| CVE | Module | Title | Fixed in |
|-----|--------|-------|----------|
| CVE-2026-32700 | confirmable | "change email" race condition lets a user confirm an email they don't control | >= 5.0.3 |
| CVE-2026-40295 | timeoutable | Open redirect via unvalidated `request.referrer` in the timeout handler | >= 5.0.4 |

Neither vulnerable module is enabled in this app. `User` includes:
`recoverable, rememberable, validatable, invitable, two_factor_authenticatable,
lockable`. So real-world exploit exposure is effectively nil — but bundler-audit
flags by gem version, not by enabled module, so the upgrade is still required to
clear the audit and remove the ignore entries.

Latest Devise is **5.0.4**, which fixes both CVEs.

## Compatibility check (done during brainstorming)

- **Ruby / Rails:** Devise 5.0 requires Ruby >= 2.7, Rails >= 7.0. App is on
  Ruby 3.3.8 / Rails 7.2.3.1. ✓
- **Dependent gems:** `devise-two-factor` (6.4.0, requires `devise >= 4.0, < 6.0`)
  and `devise_invitable` (2.0.12, requires `devise >= 4.6`) both allow 5.x. ✓
- **Removed APIs:** grep found zero usage of `devise_error_messages!`,
  `sign_in(..., :scope)` positional form, `Devise::TestHelpers`, the `bypass:`
  option, or `BLACKLIST_FOR_SERIALIZATION`. ✓
- **Custom views:** `app/views/devise/*` are customized copies. Devise 5.0's
  markup tweaks (`<br>`→`<p>`, password-reset button label, `data-turbo-cache` →
  `data-turbo-temporary`) do not auto-apply and are purely cosmetic. Left as-is.

## Secret key change (verified — no action required)

Devise 5.0 simplifies secret-key resolution: it always uses
`Rails.application.secret_key_base` and ignores `config.secret_key`. Devise uses
this key to sign recoverable / invitable / lockable tokens, so a value change
would invalidate in-flight password-reset and invitation links.

The app's initializer currently sets
`config.secret_key = ENV.fetch('SECRET_KEY_BASE', ...)`. In all deployed
environments (staging, uat, production), `SECRET_KEY_BASE` is set as a sealed
secret env var (`ops/dnz-kubernetes/eks/deployments/harvester/*/harvester_sealed_secrets.yaml`),
and Rails derives `secret_key_base` from that same variable. So the effective
key is identical before and after the upgrade — **existing tokens stay valid in
every environment.** The `config.secret_key` line becomes dead code in 5.0 and
is removed.

## Changes

1. **`Gemfile.lock`** — `bundle update devise` resolves `devise (5.0.4)`. No
   Gemfile change; `gem 'devise'` stays unpinned, matching current style.
2. **`config/initializers/devise.rb`** — remove the `config.secret_key = ...`
   line (dead in 5.0; the hardcoded dev fallback string was a latent footgun).
3. **`.bundler-audit.yml`** — remove `CVE-2026-32700` and `CVE-2026-40295`.
   Keep `CVE-2026-41316` (erb), `CVE-2026-47736`, `CVE-2026-47737` (puma).

## Out of scope

- Regenerating Devise views.
- puma and erb CVEs (separate branch).

## Verification

- `bundle exec rspec` — full suite passes, with attention to auth flows:
  2FA sign-in, password recovery, invitations, lockable.
- `bundle-audit check` — the two Devise CVEs no longer appear; the three
  remaining ignored CVEs still suppressed.
- Manual smoke (optional, local): OTP sign-in, password-reset email, invite flow.

## Risk

Low. No removed APIs in use, the two vulnerable modules are not enabled,
dependent gems already permit 5.x, and the signing key is unchanged in all
environments.
