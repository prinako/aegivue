# Fragment offsets and measured media timing

This change fixes the timeline planner introduced in PR #98: bounded requests at
`startSeconds > 0` must be placed at the recording start plus the **fragment
offset**, rather than at the recording start every time.

The planner accepts `firstPresentationSeconds` as a **measured value from
the actual remuxed output**. The current fragment endpoint still does not
provide such a measurement. Never substitute the requested start offset,
source-file packet PTS, or a hardcoded zero for measured output PTS.

## Follow-on integration

1. Capture the actual remuxed bytes in a bounded seek window or inspect their
   ISO BMFF `moof/traf/tfdt` and `trun` boxes, including timescales and
   composition offsets.
2. Determine first playable presentation time and duration **per track**.
3. Expose authoritative timing metadata alongside the media payload.
4. Ensure the client processes `SourceBuffer.updateend`, init segments,
   codec changes, random-access frames, gaps and overlaps.
5. Run a browser integration test against at least two actual adjacent camera
   recordings using a **single** video element and SourceBuffer.

This PR does not claim that playback is continuous and must remain draft.
