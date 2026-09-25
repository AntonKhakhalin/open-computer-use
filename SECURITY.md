# Security Policy

## Supported versions

Security fixes are provided only for the latest release (the npm `open-computer-use` latest tag).

## Reporting vulnerabilities

If you find a suspected security vulnerability, please do not open a public issue.

Report it through GitHub's private vulnerability reporting channel:

```text
https://github.com/AntonKhakhalin/open-computer-use/security/advisories/new
```

Please include, where possible:

- The scope of impact and potential risks.
- The affected platforms (macOS / Windows / Linux) and installation method (npm version, agent client).
- Reproduction steps or a PoC.
- Known mitigations or temporary workarounds.

## What to expect

- After receiving a report, we will acknowledge it and assess the scope of impact as soon as possible.
- The fix will be delivered through the regular release process after coordination, and the reporter will be credited in the release notes (unless they request to remain anonymous).

## Scope

`open-computer-use` performs Accessibility / keyboard-and-mouse automation within a signed-in local desktop session and inherently holds high privileges. Use it only on machines you own or are explicitly authorized to control; risks introduced by the manner of use itself are outside this repository's security scope.
