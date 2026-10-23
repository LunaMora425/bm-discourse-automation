# **Barbermonger Custom Automation** Plugin

**Plugin Summary**

Extending the Discourse Automation plugin for BM's use case. Specifically aiming to add an automatic archival process and the ability to auto-move search topics posted in the wrong place.

## Features

| Feature | Settings | What it does |
|---|---|---|
| Archive mover | `bm_archive_category_map` | Moves archived (and optionally auto-closed) topics to a paired archive category |
| Welcome-PM group filter | — | Stops welcome PMs from also landing in the site contact group's inbox |
| Ad cooldown | `bm_ad_cooldown_categories`, `bm_ad_cooldown_days` | In the listed categories (one shared pool), a member who started a topic or posted in their own topic within the cooldown can't start another or bump. Replies in other members' topics are unaffected. Staff exempt |
| No pairing codes in titles | `bm_title_pairing_categories`, `bm_title_pairing_tag_groups`, `bm_title_pairing_slash_words` | Blocks pairing codes (MxF, M4F, M/M, F//, …) built from the pairing tag group in new or edited titles. Existing codes in old titles are allowed to stay. Staff exempt |
| Quiet staff edits | `bm_quiet_staff_edits` | Staff edits to someone else's post or title don't send an "edited" notification unless the edit reason is filled in. The edit still shows in the history |

Everything is gated by `bm_discourse_automation_enabled`. The new features are server-side only, so they can be deployed without a rebuild (`git pull` in the container + `sv 2 unicorn`).

<!-- For more information, please see: **url to meta topic** -->
