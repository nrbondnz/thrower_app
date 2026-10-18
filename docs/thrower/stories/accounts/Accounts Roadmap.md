# Accounts Roadmap

How backlog #4 (**Accounts**) grows from friends typed into one phone to a game centre where every friend has the app, joins a session run from the host's phone, and owns their own throws and videos. Written 2026-10-18 from a conversation with Nigel. **Stage 1 comes first** (Nigel, 2026-10-18).

This is a roadmap, not a story. Each stage becomes its own `story-checkpoint-<slug>.md` when it starts, planned with the Story Agent. Each stage must be useful on its own. Nothing built in one stage should be thrown away by the next.

Related: [[backlog]] #4 (Accounts), #5 (Game modes: typed names), #11 ([[story-checkpoint-record-and-share]]); [[Design Decisions]] → User Accounts Required; Game History.

---

## The Destination

- A **host** runs a session on their phone. It's the phone on the stand, with the camera watching the board or boards.
- **Friends** each have the app and are signed in. They **join** the host's session, see the scores live on their own phones, and take their turns.
- Each thrower's **throws are recorded on video**. The clips belong to the **thrower**, who shares them on the internet as they choose.
- Over time: history that follows each person, friends lists, leaderboards, leagues and achievements, and perhaps matches between two venues.

---

## Stages

| Stage | What it adds | Backend | Story |
|---|---|---|---|
| **1. Friends on the phone** | A list of friends kept on the phone; choose who plays; history by friend | None | Next: to be planned |
| **2. The owner's account** | The phone's user signs in; friends list and history backed up and restored on a new phone | Sign-in, storage | — |
| **3. Friends with accounts** | A friend on the phone is **linked** to their own account; games played on the host's phone appear in their history | Friends, shared records | — |
| **4. Join a live session** | The host's phone runs a session; friends join from their own phones; live scores, turns and corrections on each thrower's phone | Live sync (server or local Wi-Fi) | — |
| **5. Throws on video, owned by the thrower** | The host records each throw (#11); each friend's clips are delivered to them to keep or share | Clip delivery | Builds on #11 |
| **6. Game centre** | Leaderboards, leagues, achievements, remote matches | All of the above | — |

### Stage 1: Friends on the Phone

**Goal:** a night with friends feels like *their* game. Players have names, and each friend's history is kept, all on the one phone with no sign-in.

- **Friends list:** add, rename and remove friends ("Mark", "Sam"). The phone's owner is a friend too ("Me", renamable).
- **Choosing players:** Play's setup screen picks who is playing, by name, instead of "Player 1" and "Player 2". Play, two-target Play, History and the instructions use the names.
- **History by friend:** each game records who played. History can show one friend's games and their best scores.
- **Identity from day one:** every friend gets a **lasting ID** (not their name, which can change, or their seat). Later stages *link* that ID to an account, so nothing needs migrating.
- **Data model:**
  - A `Friend` (`id`, `name`), with a `FriendsList` interface and a file-backed implementation. It lives in an edge folder like `lib/history/`, following the `GameHistory` pattern: an interface, safe writes, damaged files set aside and never deleted.
  - `GameRecord` **version 2**: each player has a friend ID and the name at the time of the game.
  - Version 1 files still read: their players become unnamed "Player 1" and "Player 2" with no ID.
- **No backend, nothing leaves the phone.**
- **Open questions** (to settle when planning the story):
  - More than 2 players on one target, now that they have names?
  - Is removing a friend allowed when they have games in History? Their past games would keep the name.
  - Is a quick "guest" player needed, someone who isn't added to the list?
  - Should Quick draw show names too?

### Stage 2: The Owner's Account

**Goal:** the phone's user signs in, and their friends list and history are safe if the phone is lost or replaced.

- **Sign-in:** the chosen provider behind `AuthService`, which already exists (`lib/auth/`; `authServiceProvider` throws until overridden).
- **Backup and restore:** `FriendsList` and `GameHistory` get backend implementations, or a sync layer over the file ones.
  - **Offline-first:** venues often have poor signal, so the phone stays the source of truth and syncs when it can.
- **The backend choice is made here** (see Open Decisions). Revisit CI/CD (A8) and the branch model (a dev/prod split) at the same time.
- **Store rules:**
  - Sign in with Apple is required on iOS if any other social sign-in is offered.
  - **Account deletion inside the app** is required on both stores.
  - Privacy labels and a privacy policy are needed.
- **Review Agent:** a new network service and data leaving the device (§4, §5, §8).

### Stage 3: Friends with Accounts

**Goal:** friends who have the app see the games they played on someone else's phone.

- **Linking:** a friend on the host's phone is linked to a real account, by an invite link or a QR code shown on the host's phone. Link before the game, not during it (safety, below).
- **Shared records:** a finished game is shared with every linked player, and appears in their own history.
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
- **Lasting IDs, never names or seats:** a player is a friend ID from stage 1 on, and accounts are linked to it later.
- **The host's phone is the referee:** scoring and the camera stay on the host's phone (on-device vision, [[Design Decisions]]). Other phones request; the host decides.
- **Offline-first:** a game never depends on signal. Syncing happens afterwards.
- **Behind interfaces:** `AuthService`, `FriendsList`, `GameHistory`, and later a `SessionLink`, so the backend stays at the edges, as the camera and sound plugins do.
- **Safety:** nothing should call anyone to the board or to the host's phone during a game. Linking and joining happen before the game; from stage 4, corrections come from the thrower's own phone.

---

## Open Decisions

| Decision | Needed by | Options | Leaning |
|---|---|---|---|
| **Backend and sign-in provider** | Stage 2 | **Firebase** (sign-in, a live database and storage in one; fastest to stage 4); **Supabase** (Postgres, live updates, open source); **AWS** (Cognito, AppSync and S3; the stack Nigel's other projects use; more setup) | Not yet chosen: weigh Firebase against AWS at stage 2 |
| **Where video goes** | Stage 5 | **Phone to phone** (clips sent straight to the thrower; the app never hosts video; cheaper; sharing through their own share sheet) or **cloud** (stored; allows sharing later and clips on leaderboards; storage costs, consent and moderation) | Phone to phone first (not yet confirmed) |
| **Live session transport** | Stage 4 | Server, local network or Bluetooth, or both | Decide when planning stage 4 |
| **Ownership rule** | Stage 3 | As above | Proposed |
| **Age** | Stage 2 | Knife throwing: are accounts adults only (an age check at sign-up), or are under-18s allowed with care? | To ask |

---

## Changes Log

- **2026-10-18:** Written from Nigel's description of the destination (friends on one phone first; ultimately a game centre where friends sign in, join the host's session, and share their own throw videos). Nigel: stage 1 first.
