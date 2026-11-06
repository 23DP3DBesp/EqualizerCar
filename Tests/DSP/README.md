# DSP regression checks

Run from the repository root on macOS with Xcode installed:

```sh
clang++ -std=c++17 -O1 -g -fsanitize=address,undefined Tests/DSP/KernelTests.cpp -o /tmp/ec-dsp-tests
/tmp/ec-dsp-tests
clang++ -std=c++17 -O2 -fobjc-arc -framework Foundation -framework AVFoundation -framework AudioToolbox EqualizerCar/DSP/Realtime/ECProcessingAudioUnit.mm Tests/DSP/AudioUnitRenderTests.mm -o /tmp/ec-au-tests
/tmp/ec-au-tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Tests/DSP/check_presets.py
```

The Audio Unit test needs access to Core Audio component registration; restricted sandboxes can return error -3000. It renders offline and does not play through speakers.

Kernel checks cover 26 processing modes, mono/stereo at 44.1/48/96 kHz, signal differences, bypass and latency, dynamics, peak ceiling, stereo width, bass mono, harmonics, automation, and block-size invariance. The AU test covers actual registration, resource reallocation, and a complete offline AVAudioEngine chain. Preset checks exercise production decoding, normalization and encoding, including older JSON.

## Processing behavior

Parameters and bypass use a 20 ms sample-domain smoothing constant. Disabled processors skip their effect calculations after fading out. The native Apple equalizer uses coalesced control updates; these are not sample-accurate AU ramps. Render processing allocates no buffers and takes no locks; buffers are prepared before rendering.

The final output protection follows output gain. Limiters use 3 ms lookahead and sample-peak detection, not certified intersample true-peak limiting. Their delayed bypass maintains timing.

Tape Saturation is a tape-style nonlinear effect with interpolated oversampling and filtering, not a physical tape-machine model. Spatial, Surround and Stereo 3D are stereo effects, not discrete multichannel or Dolby processing. Polarity inversion is mathematically effective but usually inaudible in isolation. Hum and engine filters attenuate frequencies present in the source; they cannot remove interference introduced downstream in a car amplifier. Engine frequency is manually controlled.

These checks establish numerical and integration behavior. They do not establish subjective sound quality or performance on a physical iPhone. Listening comparisons and device profiling remain useful before release.

Launch the Debug simulator app with `--audio-smoke-test` for an opt-in full app check.
It creates temporary quiet test tones, exercises mono/stereo files at 44.1/48 kHz,
engine stop/restart, seek, EQ replacement and the three car effects. Success prints
`AUDIO_SMOKE_PASS` in the console. This flag is absent from Release builds.

Subsonic Filter uses a fourth-order Butterworth high-pass (20–60 Hz).
Vocal Clarity combines a broad 300 Hz cut and a 2.5 kHz presence boost; it is not source separation.
Night Mode uses stereo-linked compression with up to 6 dB makeup gain; final output protection remains downstream.
