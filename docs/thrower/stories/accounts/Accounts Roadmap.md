# Accounts Roadmap

How backlog #4 (**Accounts**) grows from friends typed into one phone to a game centre where every friend has the app, joins a session run from the host's phone, and owns their own throws and videos. Written 2026-10-18 from a conversation with Nigel. **Stage 1 comes first** (Nigel, 2026-10-18).

This is a roadmap, not a story. Each stage becomes its own `story-checkpoint-<slug>.md` when it starts, planned with the Story Agent. Each stage must be useful on its own. Nothing built in one stage should be thrown away by the next.

Related: [[Requirements Index]] (what each stage delivers: [[Player Names]], [[Remote Play]], [[Results Sharing]], [[Rankings]], [[Competitions and Prizes]]); [[backlog]] #4 (Accounts), #5 (Game modes: typed names), #11 ([[story-checkpoint-record-and-share]]); [[Design Decisions]] → User Accounts Required; Game History.

---

## The Destination

- A **host** runs a session on their phone. It's the phone on the stand, with the camera watching the board or boards.
- **Friends** each have the app and are signed in. They **join** the host's session, see the scores live on their own phones, and take their turns.
- Each thrower's **throws are recorded on video**. The clips belong to the **thrower**, who shares them on the internet as they choose.
- Over time: history that follows each person, friends lists, leaderboards, leagues and achievements, and perhaps matches between two venues.

---

## App Users, Players and Friends (Nigel, 2026-10-19)

*"Each app user has an account. They can name players and can send videos using share, but for them to be fully integrated they will have to also have the app and become friends with this app user."* And: *"they can name players but they just have scores (they could just as well be player 2). Friends, also have the app and have linked their account to this user so will get their throws recorded on their app."*

| Term | Who | What they get |
|---|---|---|
| **App user** | Whoever runs the app on their phone; has an **account** | Their own history, settings and subscription |
| **Named player** | A **name on a seat** of one game ("Mark" instead of "Player 2"): a label, nothing more | Their scores in that game, on the app user's phone only. Clips can be sent to them with the phone's **Share** (any app). They don't need the app |
| **Friend** | Another app user who has **linked their account** to this app user | Fully integrated: their throws are **recorded on their own app** (history, clips), they join sessions, and they rank in the Game Centre |

- **A named player is not a person in the app:** no list, no history of their own, no ID. A name typed for one game.
- **A seat holds either a named player or a friend.** When Mark gets the app and links up, the app user picks him as a friend from then on. Games where he was a named player stay on the app user's phone under "Mark"; they don't move to his app.
- **Signing in is not a gate for scoring** (Claude, 2026-10-19, to confirm): Apple's review rules say that if an app's core works without an account, people must be able to use it without logging in. Scoring on one phone works without one. So the app scores without signing in, and asks for the account when the user wants what it gives: backup, friends, the Game Centre, a subscription (whose 14-day trial starts then: [[Subscriptions]]).
- **Sharing clips with players needs no account:** the share sheet sends them anywhere ([[Results Sharing]]), so Record and share (backlog #11) can come before the backend.

---

## Stages

| Stage | What it adds | Backend | Story |
|---|---|---|---|
| **1. Named players** | Each seat can be given a name in place of "Player 1" / "Player 2"; History shows the names | None | Next: to be planned |
| **2. The app user's account** | The app user signs in (when they want backup, friends, the Game Centre or a subscription, not to score); history backed up and restored on a new phone | Sign-in, storage, payments | — |
| **3. Friends** | Another app user **links their account** to this app user and becomes a **friend**; a seat can be a friend; their throws on the host's phone are **recorded on their own app** | Friends, shared records | — |
| **4. Join a live session** | The host's phone runs a session; friends join from their own phones; live scores, turns and corrections on each thrower's phone | Live sync (server or local Wi-Fi) | — |
| **5. Throws on video, owned by the thrower** | The host records each throw (#11); each friend's clips are delivered to them to keep or share | Clip delivery | Builds on #11 |
| **6. Game centre** | Leaderboards, leagues, achievements, remote matches | All of the above | — |

### Stage 1: Named Players

**Goal:** a night with friends feels like *their* game: "Mark wins", not "Player 2 wins". All on the one phone, with no sign-in. (Was "Friends on the phone", then "Players on the phone", with a list of players and a history for each; simplified 2026-10-19 by Nigel: a named player "just has scores", like Player 2.)

- **Names on seats:** Play's setup screen lets each seat be given a name (optional; blank stays "Player 1" / "Player 2"). Play, two-target Play, the result and History use the names.
- **Data model:** the game's players carry an optional name (`Match` / `GameNotifier`); `GameRecord` **version 2** stores each player's name. Version 1 files still read, with no names.
- **No player list, no history by player, no IDs:** a name is a label for one game.
- **No backend, nothing leaves the phone.**
- **Open questions** (to settle when planning the story):
  - Remember recent names, so they can be picked rather than typed each time? (A convenience list, not players with histories.)
  - The app user's own seat: "Me", or their name, by default?
  - More than 2 players on one target?
  - Names in Quick draw too?

### Stage 2: The App User's Account

**Goal:** the app user signs in (when they want what an account gives, not to score), and their history is safe if the phone is lost or replaced.

- **Sign-in:** the chosen provider behind `AuthService`, which already exists (`lib/auth/`; `authServiceProvider` throws until overridden).
- **Backup and restore:** `GameHistory` gets a backend implementation, or a sync layer over the file ones.
  - **Offline-first:** venues often have poor signal, so the phone stays the source of truth and syncs when it can.
- **The backend choice is made here** (see Open Decisions). Revisit CI/CD (A8) and the branch model (a dev/prod split) at the same time.
- **Store rules:**
  - Sign in with Apple is required on iOS if any other social sign-in is offered.
  - **Account deletion inside the app** is required on both stores.
  - Privacy labels and a privacy policy are needed.
- **Review Agent:** a new network service and data leaving the device (§4, §5, §8).

### Stage 3: Friends

**Goal:** a friend's throws on the host's phone are recorded on the friend's own app.

- **Linking:** another app user links their account to this app user, by an invite link or a QR code shown on the host's phone, and becomes a **friend**. Link before the game, not during it (safety, below).
- **Seats:** a seat is a named player (a label) or a friend (picked from the friends list).
- **Shared records:** a finished game's throws by a friend are sent to that friend's app and appear in their own history. Named players' scores stay on the host's phone.
- **Ownership:** each player's throws belong to them (see Ownership Rule). The host's copy keeps the game.
- **Friends lists** become two-way: accepting an invite, and removing a friend.

### Stage 4: Join a Live Session

**Goal:** friends play from their own phones while the host's phone does the watching.

- **Session:** the host starts a session. Friends join, by scanning the host's QR code before the game or from a list of nearby sessions.
- **The host's phone stays the referee.** It runs the camera, the scoring and the `Match`. Friends' phones show the live scores and whose turn it is.
- **From a thrower's own phone:** see their scores; **correct a score** (a request the host's phone applies, and perhaps both players agree to in a dispute); say "I'm up".
- **Safety gain:** score corrections and results no longer need anyone to walk to a phone beside the lane, a risk the score-corrections and Quick draw stories had to work around (Review Agent §7).
- **Transport:** behind an interface (a `SessionLink`), so it can be a server, the local network, or both. Choose when planning.
  - **Server:** works anywhere with signal.
  - **Local network or Bluetooth:** works without signal, but is harder across iOS and Android.
- **Two targets:** each board's thrower joins on their own phone, as the two-target screen's Player 1 and Player 2 already are.

### Stage 5: Throws on Video, Owned by the Thrower

**Goal:** every thrower gets their throws as clips, and shares them on the internet as they see fit.

- **Recording:** builds on #11 ([[story-checkpoint-record-and-share]]). Play records each throw as a short clip, with the scoring overlays drawn on when sharing.
- **Delivery:** each clip goes to the thrower's account or phone, not just the host's. The thrower decides whether to share it, through their own phone's share sheet.
- **Consent:** other people in the frame (other throwers, people collecting knives, bystanders). The app should make clear who is being filmed, and keep clips private until their owner shares them.
- **Review Agent:** video of people leaving the device is the largest privacy step in the roadmap (§5).

### Stage 6: Game Centre

**Goal:** a community around the app.

- Leaderboards (by game length and mode), leagues, achievements.
- Perhaps **remote matches**: two venues, each with its own host phone, playing one match.
- Perhaps Apple Game Center and Google Play Games for achievements. They can't link friends across iPhone and Android, so they'd be an add-on, never the friends system.
- Payments (deferred in [[Design Decisions]]) may belong here.

---

## Rules That Hold Across Every Stage

- **Ownership rule** (proposed 2026-10-18, to confirm): **the host's phone records a throw, but the thrower owns it**: their scores, their clips, their choice to share or delete.
- **Friends are accounts, named players are labels:** only a friend's throws leave the host's phone (to their own app); a named player's scores stay with the game.
- **The host's phone is the referee:** scoring and the camera stay on the host's phone (on-device vision, [[Design Decisions]]). Other phones request; the host decides.
- **Offline-first:** a game never depends on signal. Syncing happens afterwards.
- **Behind interfaces:** `AuthService`, `GameHistory`, later a friends service, and later a `SessionLink`, so the backend stays at the edges, as the camera and sound plugins do.
- **Safety:** nothing should call anyone to the board or to the host's phone during a game. Linking and joining happen before the game; from stage 4, corrections come from the thrower's own phone.

---

## Open Decisions

| Decision | Needed by | Options | Leaning |
|---|---|---|---|
| **Backend and sign-in provider** | Stage 2 | **Firebase** (sign-in, a live database and storage in one; fastest to stage 4); **Supabase** (Postgres, live updates, open source); **AWS** (Cognito, AppSync and S3; the stack Nigel's other projects use; more setup) | Not yet chosen: weigh Firebase against AWS at stage 2 |
| **Where video goes** | Stage 5 | **Phone to phone** (clips sent straight to the thrower; the app never hosts video; cheaper; sharing through their own share sheet) or **cloud** (stored; allows sharing later and clips on leaderboards; storage costs, consent and moderation) | Phone to phone first (not yet confirmed) |
| **Live session transport** | Stage 4 | Server, local network or Bluetooth, or both | Decide when planning stage 4 |
| **Ownership rule** | Stage 3 | As above | Proposed |
| **Subscriptions** | Stage 2 (payments come with accounts) | Nigel, 2026-10-19: 14 days free, then subscribe, or services denied or degraded (no Game Centre uploads, no Quick draw). See [[Subscriptions]] | Degrade, not deny: core scoring free, online and video features paid; the store's 2-week trial (proposed) |
| **Age** | Stage 2 | Knife throwing: are accounts adults only (an age check at sign-up), or are under-18s allowed with care? | To ask |

---

## Changes Log

- **2026-10-19:** Nigel's model of app users, named players and friends added; signing in not a gate for scoring (proposed). Stage 1 simplified to **Named players** (a name on a seat, no player list, history or IDs); friends link their accounts and get their throws on their own app (stage 3).
- **2026-10-18:** Written from Nigel's description of the destination (friends on one phone first; ultimately a game centre where friends sign in, join the host's session, and share their own throw videos). Nigel: stage 1 first.
