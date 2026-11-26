# fMP4 track timing parser (prototype)

`readFragmentTimings(Buffer)` extracts `mdhd` timescales, `tfhd` default sample durations, `tfdt` decode-time origins, and `trun` sample durations/composition-time offsets. It returns per-track minimum PTS, initial DTS, maximum presentation end and sample count.

This is an **offline, bounded parser prototype**. It currently requires explicit durations in `trun` or `tfhd` and does **not** resolve `trex` defaults, movie edit lists, track-specific media data payload validity, optional encryption, stream profiles, or asynchronous parsing. It does not normalize or rewrite MP4 boxes. Very long/corrupt files may be rejected. The API route is unchanged: the streaming response is not buffered for metadata and the parser output is not yet exposed to clients.

Follow up: verify actual FFmpeg-produced MP4 fragments using real Aegivue recordings; compare packet PTS/DTS against FFprobe, including B-frames and AAC. Refine tfhd/trun defaults, box bounds and composition semantics before using output to set MSE timestamps. Then integrate accurate timing metadata via a reliable bounded media+metadata contract. Browser continuity and Flutter remain pending.
