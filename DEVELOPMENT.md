# Dutch support — implementation and validation

This fork preserves the MIT license and attribution to Sam Pop. Work takes place on `feature/dutch-language-support`; `main` is unchanged until review.

## Validation gates

- [ ] Baseline macOS build and upstream unit tests
- [ ] Multilingual model catalog and language compatibility
- [ ] Dutch / English / Auto inference in batch and live modes
- [ ] Conservative Dutch correction and opt-in spoken punctuation
- [ ] Dutch interface and onboarding
- [ ] Automated regression tests
- [ ] At least 50 Dutch audio evaluation prompts
- [ ] Real audio recordings, accuracy and latency measurements
- [ ] Manual Mac tests: TextEdit, Chrome, Slack, ChatGPT, PyCharm, Mail
- [ ] Prerelease DMG and checksum after validation/approval

The editing environment is Linux, not macOS. A CI build does not verify microphone permissions, text injection, audio quality or user experience. No real-audio results are claimed before recordings have been evaluated. Do not publish a stable release until manual testing is complete.
