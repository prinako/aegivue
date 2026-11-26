# Experimental lookahead scheduler

Opt-in `AegivueTimelineLookahead` queues at most one fragment operation at a time, only when a playlist window begins within `aheadSeconds` of the playhead, and requests removal of old buffered data through the existing stream's trim method. Playlist windows must be ordered and non-overlapping.

It is **not integrated into Flutter**. A scheduler tick must be driven by the host; no timer or automatic background fetch is installed. A seek that changes playlist while a prior fetch is pending does not cancel that fetch: callers must dispose/reset their coordinator when seeking across periods. A failed fetch reports an error and can retry on a later tick. The stream still needs robust QuotaExceededError recovery, actual buffering caps, and browser verification. Real camera clips, gaps and audio remain unverified.
