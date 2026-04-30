# Admin Review Process – MindDuel

## Flagging system

Users are automatically flagged client-side when their average response time is under 400 ms across 5 or more rounds. This is stored in `UserDefaults` (`isFlagged = true`) and reflected in the scoreboard and profile views with a red flag icon.

When backend is implemented (M2+), flagging must move server-side where timing data is validated independently.

## How to identify flagged users

1. Open the Scoreboard (Global tab)
2. Flagged users display a 🚩 icon next to their username
3. Tapping a flagged user's profile shows the explanation modal

## Manual review steps

1. **Gather evidence** – Pull the user's round history from the database: `SELECT * FROM rounds WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`
2. **Check average response time** – Calculate `AVG(answer_time_ms)` across rounds. Under 400 ms consistently is suspicious.
3. **Check streak** – Look for unbroken correct streaks over 20+ questions, especially on high difficulty levels.
4. **Cross-reference device** – Check if multiple accounts originate from the same device fingerprint.

## Possible outcomes

| Verdict | Action |
|---|---|
| False positive | Remove flag via admin API: `PATCH /admin/users/:id { "flagged": false }` |
| Confirmed cheating | Suspend account: `PATCH /admin/users/:id { "suspended": true }` |
| Unclear | Leave flag, monitor for 7 more days |

## Push notifications (APNs) – deferred to M5

APNs requires:
- Apple Developer account with Push Notifications entitlement
- Backend endpoint to store/update APNs device tokens per user
- Server-side trigger on friend request and game invite events

Implementation is planned for M5 (Flerspiller) when the WebSocket backend is in place.
