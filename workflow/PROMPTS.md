# Prompt kit (copy, paste, don't improvise)

These are written for an agent with the **official Roblox Studio MCP** connected. Replace the bracketed bits. The whole point is that every prompt ends with a *proof requirement* — that's what stops the "done but broken" loop.

---

## 1. Session start (run once per session)

```
You are building [GAME NAME] in the open Studio place. You have Studio MCP tools.

Before you write any code:
1. get_studio_state — tell me the play state and available datamodel types.
2. list_roblox_studios — confirm which place is open.
3. script_read ReplicatedStorage.GDD.02_Milestones and summarize the milestones
   you believe are complete, based on ReplicatedStorage.GDD.Progress.
4. script_read ReplicatedStorage.GDD.JOURNAL (last 3 entries) and tell me the
   last thing that failed.

Do not propose work yet. Just report those four things.
```

Why: it forces the agent to read reality (place, progress, failure history) instead of starting from a flattering guess.

---

## 2. Per-milestone (the one you'll use most)

```
Implement Milestone [N] — "[NAME]" — from ReplicatedStorage.GDD.02_Milestones.

Scope: only the files/tasks listed under M[N]. Nothing else, even if you notice
something broken. If you notice a bug elsewhere, add it to GDD.JOURNAL under
"BACKLOG" and continue.

Process, in this exact order, and show me each step's output:
1. search_game_tree the paths you're about to touch. Report what exists.
2. multi_edit — one module at a time, with a matching test in Tests/Suites.
3. execute_luau (Edit): assert every instance path you created exists, with the
   correct class, and print a short tree.
4. start_stop_play (play).
5. get_console_output: must be zero errors. Paste it.
6. character_navigation + user_keyboard_input/user_mouse_input to perform the
   real player action this milestone is about.
7. execute_luau (Server): assert the numbers from GDD.01_Mechanics. Print
   before/after values.
8. screen_capture: describe 3 concrete visible facts from the image.
9. get_console_output again: still zero errors.
10. start_stop_play (stop). save_place.

Then report in this format:
- FILES: paths changed
- TESTS: the literal "SUMMARY x/y" line and any FAIL lines
- NUMBERS: every measured value vs the spec value
- VISIBLE: the 3 facts from the screenshot
- GAPS: anything that missed the spec by >5%, as a number
- NEXT: the single next step

You may not use the words "should", "likely", "probably", "seems" about
behaviour. If you didn't run it, don't claim it. Only flip
Progress.M[N] to true after 3–10 all pass.
```

---

## 3. "Prove it" (when you doubt it — cheap, use often)

```
You claim [FEATURE] is done. Prove it without showing me any code:

a. execute_luau to query the live state that proves it.
b. Do the player action that exercises it (character_navigation / inputs).
c. Show the before and after values.
d. screen_capture it.
e. Paste get_console_output.

If any of a–e is not possible, say exactly which one and why. "It should work"
is not an acceptable answer to any of them.
```

---

## 4. Visual review (after the agent builds something)

```
screen_capture from [POSITION] looking at [TARGET]. Then critique your own build
against ReplicatedStorage.GDD.03_ArtDirection and [FOLDER]/images/[FILE].png:

1. Silhouette: can you tell what each object is from 100 studs? What reads
   worst?
2. Scale: compare the player character to the build. List anything smaller than
   3 studs or taller than 40 that shouldn't be.
3. Palette: list every colour in the shot; flag any that is not in the
   art-direction palette.
4. Readability: from the spawn, can a new player see where to go next? Point to
   the exact part of the image that tells them.
5. Then fix the two worst items and screen_capture again from the same camera.
```

Why this works: "does it look good" gets a compliment. "Flag colours not in the palette" gets an edit.

---

## 5. Debugging (bounded, no thrashing)

```
Bug: [ONE SENTENCE]. Repro: [STEPS]. Expected: [NUMBER/BEHAVIOUR].

Rules:
- Max 3 attempted fixes. After each: run the repro, paste get_console_output.
- Never silence an error with pcall to make the console clean.
- Before fixing, print the 3 most relevant values at the failure point.
- If a fix changes behaviour you can't explain, revert it with git and say so.
- After 3 failures: stop, write a JOURNAL entry, and offer two different
  approaches with one tradeoff each. Do not implement a 4th guess.
```

---

## 6. Full-game audit (run weekly, it's remarkably effective)

```
Audit the place against the GDD. Do not change anything yet.

1. search_game_tree the whole game at depth 3. Build a checklist of what exists
   vs GDD.02_Milestones.
2. script_grep for: "pcall(" (silent failures), "task.wait(" inside
   RunService loops (double loops), "workspace.Gravity" (global gravity bugs),
   "GetService(\"DataStoreService\")" (is saving versioned + locked?),
   "RemoteEvent" (are they all validated server-side?).
3. execute_luau (Edit) to count: total parts, total scripts, total RemoteEvents,
   total DataStore keys written per minute (estimate from code).
4. Report a table: GAP | SEVERITY | EVIDENCE (a path, a count, or a grep hit) |
   FIX COST (S/M/L).

Sort by severity. No opinions without evidence. Then wait for me to pick.
```

---

## 7. Handoff (end of session)

```
Write a JOURNAL entry in ReplicatedStorage.GDD.JOURNAL:
- date, milestone state (which are true)
- what changed (paths)
- what is verified vs merely written
- the exact failure you left behind, with its error text
- the single next step, specific enough that a fresh session can start cold
Then save_place. Don't summarize in chat — the JOURNAL is the handoff.
```

---

## 8. Anti-patterns that keep you in the 3-attempts loop

| Don't say | Say |
|---|---|
| "Make the tycoon better" | "Make pump_2 purchase set rate from 1.0 to 1.55/s ±0.01 and prove cash deducts by exactly 2,500." |
| "Fix the bug" | "`RequestPurchase` succeeds twice on double-click; prove one purchase with a mutex." |
| "It doesn't work" | "Console shows: `attempt to index nil with 'Cash'` at EconomyService:42. Fix and paste console." |
| "Add polish" | "Add a 0.15 s scale punch + 220 Hz blip on every purchase; screenshot mid-punch." |
| "Build the whole game" | One milestone, one module, one test, one proof. Repeat 30 times. |
