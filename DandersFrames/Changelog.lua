local addonName, DF = ...
DF.BUILD_DATE = "2026-03-14T20:35:32Z"
DF.RELEASE_CHANNEL = "release"
DF.CHANGELOG_TEXT = [===[
# DandersFrames Changelog

## [4.1.0] - 2026-03-14

### New Features
* (Position) **Permanent Mover handle** — a small always-visible drag handle on frames for repositioning without unlocking, with customizable position, size, offset, colors, show-on-hover with fade animation, hide-in-combat option, and red combat indicator
* (Position) **Permanent Mover quick actions** — left-click, right-click, shift+left-click, and shift+right-click can be bound to 13 preset actions including open settings, quick switch profile/click-cast profile, cycle profiles, toggle test mode, unlock frames, toggle solo mode, ready check, pull timer, reset position, and reload UI
* (Position) **Permanent Mover attach to unit** — handle can be attached to the container, first visible unit, or last visible unit so it follows the group size
* (Position) **Hide drag overlay** checkbox in the unlock panel to hide the blue drag area while keeping frames draggable
* (Dispel Overlay) **Color Name Text** — optional checkbox to color the unit's name text with the dispel type color when a dispellable debuff is present
* (Aura Designer) **Expiring pulsate for icon, square, and health bar indicators** — borders and fills can now pulse when an aura is about to expire
* (Aura Designer) **Expiring whole alpha pulse** — entire icon/square pulses its alpha when expiring
* (Aura Designer) **Expiring bounce animation** — icon/square bounces up and down when expiring
* (Aura Designer) **Hide duration text above threshold** — duration text can be hidden when the remaining time is above a configurable seconds threshold (icon, square, and bar types)
* (Aura Designer) **Expiring threshold in seconds** — expiring indicators can now trigger based on remaining seconds as well as remaining percentage
* (Aura Designer) **Trigger operator (ANY / ALL)** — indicators with multiple trigger spells can now require all triggers to be active (AND mode) or just one (OR mode, default)
* (Aura Designer) **Duration priority (Highest / Lowest)** — expiring indicators on multi-trigger spells can track the highest or lowest remaining duration buff
* (Aura Designer) **Custom border mode** — border indicators can now use an independent overlay per aura, so multiple border indicators can be visible at the same time
* (Aura Designer) **Settings grouped in containers** — all indicator settings panels and global defaults are now organized with bordered section containers
* (Aura Designer) **Earthliving Weapon** added as a trackable Restoration Shaman aura
* (Aura Designer) **Sense Power** added as a trackable Augmentation Evoker secret aura
* (Aura Designer) **Ebon Might self-buff tracking** — Augmentation Evoker's caster self-buff (395296) is now tracked on the player via fingerprint disambiguation, with correct tooltip and buff bar dedup
* (Aura Designer) **Symbiotic Relationship linked aura system** — Restoration Druid's caster buff is detected on the player and mirrored as an indicator onto the target's frame, with OOC target resolution, tooltip-based fallback, recast detection, and buff bar dedup
* (Aura Designer) **Ancestral Vigor** added as a trackable Restoration Shaman aura
* (Aura Blacklist) **Expanded blacklist coverage** — added Rogue poisons, Shaman weapon imbuements, Blessing of the Bronze (all class variants), Paladin rites, Mage Icicles, Hunter Tip of the Spear, and Shaman Reincarnation
* (Debug) **Script Runner** — multiline Lua script input in the debug console with persistent text across sessions

### Bug Fixes
* (Position) Fixed nudge buttons causing the blue drag area to vanish
* (Auras) **Fixed taint errors from secret value comparisons** — duration hide, expiring indicators, and color curves now correctly pipe secret values through secret-aware APIs only
]===]
