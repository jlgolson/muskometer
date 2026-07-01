# Contributing

Muskometer is an open-source side project — pull requests and ideas are welcome.

## Quick start

1. Fork [jlgolson/muskometer](https://github.com/jlgolson/muskometer).
2. Clone and open the project — see **[docs/DEVELOPING.md](docs/DEVELOPING.md)** for prerequisites and layout.
3. Create a branch (`fix/menu-bar-truncation`, `feat/holiday-calendar`, etc.).
4. Make your changes.
5. Run **`scripts/verify.sh`** and make sure it passes.
6. Open a pull request with a short description of *what* and *why*.

## Guidelines

- **Keep it small.** Focused PRs are easier to review.
- **Match the tone.** Clear, focused changes — no drive-by refactors.
- **Tests appreciated.** Especially for formatters, parsers, and view model edge cases.
- **No secrets.** The app has no API keys; please don't add any.

## What we're open to

- Bug fixes and clearer error messages
- Better market-hours / holiday data
- Accessibility and menu bar UX polish
- Documentation improvements

## What we're cautious about

- New network endpoints or third-party SDKs
- Scope creep (this is a menu bar ticker, not a portfolio manager)
- Breaking changes to share-count semantics without discussion

## Questions?

Open a [GitHub issue](https://github.com/jlgolson/muskometer/issues) or email [info@muskometer.org](mailto:info@muskometer.org) — no formal CLA, just the MIT license.

Thanks for helping improve Muskometer.

— [Jordan Golson](https://jordangolson.com)