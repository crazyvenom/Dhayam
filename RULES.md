# Dhayam - Game Rules (v0.1, DRAFT for approval)

## 1. Overview
Dhayam is an online team board game for Android. Two teams, **Red** (tan coins) and **Blue** (black coins), race all 12 of their coins around a shared board into the finish oval.

## 2. Rooms and teams
- A host creates a room and gets a short code (4-6 letters/numbers, e.g. AB7K). Others join with the code.
- No account needed: players pick a name and avatar.
- Players choose Red or Blue when joining. Up to **5 players per team** (10 total). Uneven teams are fine (3v1, 5v3...). No bots are added to balance teams.
- Only the host can press **Start**, at any time.
- Host can set an optional **turn timer** (or turn it off).
- If a player disconnects or leaves, a teammate (or a bot) plays their turns until they return.
- After a game ends there is a **Rematch** button.

## 3. Pieces
- Each team has **12 coins, shared by the whole team**. Whoever's turn it is may move any coin of their team.
- Red base: top-left circle. Blue base: top-right circle.

## 4. Turn order
- Teams alternate. Inside a team, members rotate (Red 1, Blue 1, Red 2, Blue 2, ...). With uneven teams, players on the smaller team play more often.

## 5. The dice
- Two sticks are thrown together. Each stick has 4 faces: **0, 1, 2, 3**, each equally likely.
- Result = sum of the two sticks. **0 + 0 counts as 12.**
- Possible results: 1, 2, 3, 4, 5, 6, 12.

| Result | 1 | 2 | 3 | 4 | 5 | 6 | 12 |
|---|---|---|---|---|---|---|---|
| Chance (out of 16) | 2 | 3 | 4 | 3 | 2 | 1 | 1 |

- **Bonus rolls:** a result of **1, 5, 6 or 12** earns another roll. A result of **2, 3 or 4** ends rolling.
- Rolls are **collected**. When rolling ends, the player spends all collected numbers in any order, on any coins.
- A collected number with no legal move is **lost**.

## 6. Unlocking and leaving the base
- Before a player has rolled their **first 1**, none of their numbers count. They keep rolling on their turns. (Unlocking is **per player**, not per team.)
- The player's first 1 **unlocks** them and also **brings one coin out** onto the team's start square.
- After unlocking, a **1 or a 5** brings a coin out of base. Other numbers move coins already on the board.
- **The 5 rule:** while the team still has at least one coin in base, a **5 can only be used to bring a coin out**. It can't move a coin already on the board. Once the base is empty, a 5 moves coins like any other number.

## 7. Movement
- Coins move along the team route (section 9), exactly as many squares as the number spent.
- Several coins of the same team may share a square, with no special effect (no blocks).

## 8. Captures and safe squares
- Landing on a square holding an opponent's coin captures it (**all** opponent coins on it). The captured coins go back to their base and need a **1 or 5** to come out again.
- A capture gives the capturer a **bonus turn** (another roll). Getting a coin into the finish gives no bonus.
- **X squares are safe.** No captures happen there. The **first team to arrive holds the square**, and the opponent cannot land on it until it is empty.

## 9. Routes (measured from the board diagram; 79 squares per team, then the oval)
Square counts: rows = X, 5 cells, X(center), 5 cells, X. Side columns = X, 5 cells, X, 5 cells, X. Upper center column = 5 cells. Lower center column = 5 cells then the bottom X. Each diagonal = 5 cells. Each inner arm = X, 5 cells, X. Two small X squares sit beside the first cell of the lower center column.

The route has two separate layers.

**Layer 1 - outer ring:** Red goes counterclockwise, Blue goes clockwise (confirmed). **Layer 2 - the M:** after the ring both come down the center column and cross over at the bottom X: Red takes the LEFT diagonal and arm, Blue the RIGHT (confirmed).

**Red:** start on the top-left X -> right along the top strip (5 cells + center X) -> down the upper center column (5 cells + middle-row center X) -> LEFT along the middle row -> down the left column -> right along the bottom row -> up the right column -> LEFT along the right half of the middle row -> down into the RIGHT small X -> sideways into the first cell of the lower center column -> down to the bottom X -> up the LEFT diagonal -> left inner arm (X, 5 cells, X) -> finish oval.

**Blue:** start on the top-right X -> left along the top strip -> down the upper center column -> RIGHT along the middle row -> down the right column -> left along the bottom row -> up the left column -> RIGHT along the left half of the middle row -> down into the LEFT small X -> sideways into the first column cell -> bottom X -> up the RIGHT diagonal -> right inner arm -> finish oval.

- Red and Blue travel the outer ring in opposite directions and meet head-on.
- Each team has a private half of the top strip, a private small X and a private inner arm.
- The upper center column is crossed once per coin, unless the coin is captured and has to start again.

## 10. Finishing and winning
- A coin enters the oval only with an **exact roll**.
- A team wins when **all 12 coins** are inside the oval.

## 11. Extras for version 1
Emoji reactions, sound effects and music, avatars and customization, rematch, team-only always-on voice chat (with mute), text/emoji chat for everyone.

---

## Open items (to settle before coding)
1. ~~Square count~~ done (79 per team, measured from the diagram). ~~Ring direction~~ and ~~inner arms~~ confirmed by the user.
2. Where exactly each team's **start square** is (assumed: the top-left X for Red, the top-right X for Blue).
3. Can a coin **exit the safe X** square freely when the opponent is waiting? (assumed yes)
4. What if the finishing exact roll needs more squares than remain in the inner arm (assumed: that number is lost).
5. What does an **uneven team** do about turn order when a player is missing (assumed: rotation skips empty seats).
