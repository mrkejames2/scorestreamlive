# M19-G Sponsor Impression Tracking & Reporting
Tracks server-authoritative sponsor **appearances**, not viewer/device ad impressions.

Official tracking is active only in `first_half` and `second_half`. Pregame, halftime and full-time exposure is bonus/untracked. Public overlay reads never write analytics. Multiple overlay windows do not multiply counts. Presentation controls and lifecycle transitions reconcile the durable cursor. Rotation boundaries are reconstructed from M19-F presentation state. Sponsor-facing terminology is **Tracked Appearances** and **Screen Time**.

Report: `GET /api/games/{game_id}/sponsor-report`

Human acceptance:
1. Normal two-sponsor rotation.
2. Pregame/halftime exclusion.
3. Next/Previous/Hide/Show.
4. Multiple overlay windows.
5. Refresh/reconnect.
6. App restart recovery.
7. Full-time closes/finalizes the report.
