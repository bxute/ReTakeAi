## Goal
Make **Preview → Export** feel:
- Intentional (not surprising)
- Calm (no sudden fullscreen jumps)
- Decisive (clear next action)
- Consistent with rest of the app



### On Tap: `Preview Video`

**Replace modal progress dialog with inline state**

Generating preview…
This may take a few seconds.


## 2️⃣ Preview Ready State (Inline, Not Fullscreen)

### Insert a **Preview Card** at the bottom (sticky)
🎬 Preview Ready

[ Thumbnail ] 1:01 • 9:16

[ ▶ Play Preview ] [ Export Video ]

Rules:
- Do NOT autoplay
- Do NOT force fullscreen
- User explicitly chooses to play
- This matches user intent and control


## 3️⃣ Preview Playback (User-Initiated)

### On Tap: `Play Preview`

- Open **fullscreen player**
- Standard controls (play / pause / scrub)
- Clear close action (`Done`)

On close:
- Return to **same screen**
- Preview card remains visible


## 4️⃣ Export Action (Clear & Final)

### On Tap: `Export Video`

Show a **clear confirmation state**:
Exporting video…
You can leave this screen.

Rules:
- Background export allowed
- No blocking spinner
- User stays in control


## 5️⃣ Transition to Exports Screen (Clean Handoff)

After export completes:
- Automatically navigate to **Exports screen**
- Highlight the newly created export