# Audio Provenance

All current sound streams are synthesized locally by `scripts/presentation/synth_audio.gd` from sine harmonics, filtered deterministic noise and amplitude envelopes. No recordings, samples, external downloads, voice models, game assets or third-party audio packs are used.

These are original prototype engine/load, asphalt, gravel, mud, water and suspension-impact cues. They are not recordings of a real rally engine and do not claim production recording fidelity. Waveforms are generated in memory; there are no missing external audio dependencies.

M6 automated release checks verify nonzero bounded PCM peaks, separate surface/water contributions, aggregate headroom at the default volume, and pause/resume behavior. Subjective balance is still validated by listening on the release hardware; these numerical checks do not claim recording-quality sound.
