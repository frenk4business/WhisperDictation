# Dutch support — implementation and validation

This fork preserves the MIT license and attribution to Sam Pop. Work takes place on `feature/dutch-language-support`; `main` is unchanged until review.

## Validation gates

- [ ] Baseline macOS build and upstream unit tests
- [x] Multilingual model catalog and language compatibility implemented
- [x] Dutch / English / Auto inference wired in batch and live modes (runtime validation pending)
- [x] Conservative Dutch correction and opt-in spoken punctuation implemented
- [x] Dutch interface/catalog and onboarding implemented (visual inspection pending)
- [x] Automated Dutch regression tests added; existing English golden tests retained
- [x] Execute macOS XCTest and verify universal application build (149 tests, 0 failures)
- [x] 55 Dutch audio evaluation prompts and scoring script
- [ ] Real audio recordings, accuracy and latency measurements
- [ ] Manual Mac tests: TextEdit, Chrome, Slack, ChatGPT, PyCharm, Mail
- [ ] Prerelease DMG and checksum after validation/approval

The editing environment is Linux, not macOS. A CI build does not verify microphone permissions, text injection, audio quality or user experience. No real-audio results are claimed before recordings have been evaluated. Do not publish a stable release until manual testing is complete.

## Checks actually run

- Seven Python tooling tests: passed (catalog generation, format arguments,
  corpus IDs/count, evaluator, Makefile source coverage, model checksum parity).
- `bash -n scripts/download-model.sh`: passed.
- `git diff --check`: passed.
- A non-compiler Swift syntax scan found only the same five parser limitations
  present in upstream `Settings.swift`; it is **not** a Swift typecheck or build.
- After Actions was enabled, [PR run 35333165793](https://github.com/frenk4business/WhisperDictation/actions/runs/35333165793)
  passed build, test and tooling on commit `b8ddf63`: x86_64 + arm64 app,
  149 XCTest tests (including 11 Dutch tests), 7 tooling tests, 126 localized strings.
  No separate upstream baseline pass is claimed. The existing upstream CFString
  pointer compiler warning in AudioDeviceManager remains.

## Architecture and remaining limitations

Settings are captured once per recording, model loads use generation guards,
and the bridge rejects incompatible model languages at runtime. Auto results
select Dutch/English cleanup from the detected language; other languages are
passed through. Prompt text is tokenized and capped to half the model's text
context, matching the pinned whisper.cpp implementation, not a guessed word count.

NL/Auto correction batches all decoder segments within an utterance or live
VAD fragment. Multiword commands/numbers split across separate live pauses still
need a pending-tail buffer. Full-precision multilingual variants were optional
in the plan and are not added; existing English full-precision models remain.

CI now packages an ad-hoc-signed DMG test artifact and SHA-256 checksum, verifies
the image and its mounted executable, signature and Dutch localization. This
supports manual evaluation; it is not a published prerelease.

No GitHub Projects board, Developer-ID-signed/notarized app, tag or published
release has been created. Track implementation in PR #1 and this checklist;
do not mark audio/manual/release gates complete until evidence is attached.
