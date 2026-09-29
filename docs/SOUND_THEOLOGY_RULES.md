---
id: ludus-sound-theology-rules
type: audio-rules
tags: [ludus, sound, theology, bells, chant, hesychia]
version: 1.0
date: 2026-09-29
implements: public/ludus/ludus-sacred-synth.js, public/ludus/ludus-audio-manager.js
---

# Sound Theology Rules

These rules say which sounds Ludus may make, and which it may not, under
Orthodox theology and practice. They are binding for recorded assets
(voice casting, Wwise) and for the procedural stand-ins in
`public/ludus/ludus-sacred-synth.js`, which render every catalogue cue
until recordings exist.

The project constitution ("sound is a language", Taboo 4) says a sound
must carry meaning. These rules say what that meaning may be. Each rule
gives the reason (**Why**) and how the code follows it (**In code**).

Sources:

- **kolokol** (`/home/user/kolokol`): the book *Колокол*. Its
  `RESEARCH_NOTES.md` is the log of checked facts. The chapters used
  here are:
  - ch. 6 «Как Византия впустила колокол» (the semantron)
  - ch. 11 «Анатомия голоса»
  - ch. 12 «Пять частичных тонов» (partials)
  - ch. 22 «Ритм и форма звона»
  - ch. 25 «Богослужебный звон» (ringing orders)
  - ch. 26 «Колокол в церковном предании»
- **hesychasm**
  (`/home/user/hesychasm-meditation-module/src/hesychasm/breathing_patterns.py`):
  breathing timings for the Jesus Prayer.
- Patristic and canonical sources are named where they apply. When a
  wording is a common attribution and not a checked quotation, the text
  says so.

---

## (a) Worship is a cappella: only the voice sings

**Rule.** No instrument imitates liturgical singing. The game has no
organ, strings, pads, synth choirs or a "heavenly" orchestra under the
prayer. Chant appears in only two forms:

1. the **ison**: a wordless drone sung by the voice
2. **bells and the semantron**, which are signals *around* the service,
   not accompaniment *in* it

**Why.** The Orthodox Church has always sung without instruments. The
Fathers read the psalm instruments spiritually: the "lyre with living
strings" is the worshipper's own tongue and body. This image is commonly
attributed to St John Chrysostom's commentary on the Psalms. An
instrument under the chant would teach the player a liturgy that does
not exist.

**In code.** `ison()` is an additive, band-limited sawtooth.
`VOWELS` weights its harmonics with vowel formants (dark "o" and open
"a" for men, "a" for the sisters' choir), which makes it a voice and
not an instrument. The voice is:

- several singers a few cents apart
- plus an **октавист** an octave below, as in Russian choral practice

No cue mixes an ison with bells, because in the temple they are not
simultaneous: the bells call and the choir sings.

**Conflict to resolve.** `docs/SOUND_DESIGN_SYSTEM.md` plans an ney
over a pad, "modern orchestral arrangement (strings, woodwinds, harp)",
"ethereal textures (pads)" and "Gregorian chant". Under this rule those
plans are out of scope for sacred moments. Gregorian chant is Western,
not Byzantine or Znamenny. That document belongs to another owner and
should be brought in line.

## (b) Bells speak the Typikon, not a "reward ding"

**Rule.** A bell sounds only in a liturgical meaning:

| Order | Meaning | Where Ludus uses it |
|---|---|---|
| **Благовест**: measured single strokes on the largest bell | Calls to prayer; "good news" | `prayer_delivered`, `monastery_bell_toll`, `monastery_bells`, `foundational_gate` |
| **Трезвон**: all bells, in three приёма (затравка, body, удар во вся) | Feast, fullness of joy | `teaching_complete` / `blessing_sound` (short motif), `liturgical_gate`, `victory_theme` |
| **Перезвон**: large bell to small, no удар во вся | Solemn and sorrowful procession | `perezvon` |
| **Перебор**: small bell to large, then all together | Funeral, mourning | `perebor` |
| **Звон в двои**: two bells | Lenten weekdays: restraint | `ascetic_gate` |

A bell is **never** used for:

- a score going up
- an item picked up
- an attribute bonus
- a generic UI confirmation

**Why.** The meanings come from the kolokol research: `RESEARCH_NOTES.md`
«Устав звона (виды)» (after pravenc.ru «Звон», bellschool.ru), ch. 25
and ch. 22. Ch. 25 says the Typikon fixes "not only the fact of ringing
but which bell and at what moment", so the ringing "is not an ornament
of the event but its inseparable, meaningful part". A trezvon as a
coin-ding teaches the player that joy is a reward for a correct answer.
The Church rings it for the feast, which is a gift.

**In code.**

- Attribute cues are wordless voices (Wisdom rises a step, Constitution
  is a low ison with октавист) or wood (Dexterity is two semantron
  taps). They are never bells.
- "Choice made" is one light semantron tap.
- "Locked" is a muted double knock on the било.

The semantron comes before the bell because Orthodox tradition likens
its quiet wooden voice to the prophets, who come before the Gospel of
the bell. On Athos the monk walks three times around the church (ch. 6).
The first-encounter theme therefore plays three rounds of semantron and
then благовест.

### Bell acoustics used (source: kolokol ch. 12, ch. 11, RESEARCH_NOTES)

Five principal partials, as ratios to the prime:

| Partial | Definition (ch. 12) | Ratio |
|---|---|---|
| hum (унтертон) | octave below prime; the long after-sound | 0.5 |
| prime (прима) | the named note | 1.0 |
| tierce (терция) | **minor** third above prime, the "slightly sad" colour | 1.2 (just 6:5) |
| quint (квинта) | perfect fifth above prime | 1.5 |
| nominal | octave above prime; the short bright flash at the strike | 2.0 |

Russian bells are not trimmed to exact intervals the way a carillon is.
RESEARCH_NOTES «Русский звон vs западный карильон» says Russian ringing
uses the bell's full overtone spectrum. Ch. 12 says old bells stray from
the ideal, the hum and the upper partial by up to a whole tone. Each
bell therefore gets a small fixed detuning seeded by its own name:

| Partial | Detuning |
|---|---|
| hum | ±1.5 % |
| tierce, quint | ±0.6 % |
| nominal | ±1 % |

Hum and prime are doublets 0.1 to 0.5 Hz apart, which gives the slow
warble of an out-of-round bell. Decay follows ch. 12: the hum rings
longest and the nominal is shortest.

The ensemble:

- The three largest bells form a C major triad (C3, E3, G3), the design
  that RESEARCH_NOTES records for the Rostov zvonnitsa (Сысой,
  Полиелейный, Лебедь).
- Five smaller bells complete the zvon: C4, E4, G4, C5, E5.

No tempo in seconds for благовест was found in the sources. The 4 to 6
second stroke interval is a **design choice** for a "мерный, редкий"
pulse, not a sourced fact.

## (c) Sacred names and the Jesus Prayer are never a mechanic

**Rule.** The following are never a spell, a buff, a damage effect, a
score multiplier or a combo trigger:

- the Name of Jesus
- the Jesus Prayer
- the names of the Theotokos and the saints
- the sign of the cross

Prayer audio **accompanies** the player's act. It never powers anything
up: no "charging" sound, no rising sweep into an impact, no stat pop
synced to the Name.

**Why.** Using the Name as a spell is a magical use of the Name, forbidden
by the third commandment (Ex 20:7). The hesychast fathers insist that
the prayer is not a technique that produces effects. The hesychasm
module's own St Ignatius pattern carries his warning against excessive
technique ("главное - внимание к словам"). A game that rewards the Name
with damage would teach exactly the magic the tradition warns against.

**In code.**

- `prayer_vocalization` renders a *wordless* ison (`prayer_voice`). It
  does not synthesise or imitate the words.
- The ison breathes with the prayer's rhythm. The timings are copied
  from `breathing_patterns.py`:

  | Pattern | Inhale | Hold | Exhale | Hold |
  |---|---|---|---|---|
  | Athonite | 5 s | 1 s | 8 s | 1 s |
  | Sinaite | 6 s | 2 s | 8 s | 0 s |
  | Optina | 4.5 s | 0 s | 5.5 s | 0 s |
  | St Ignatius | 5 s | 0.5 s | 6 s | 0.5 s |
  | Basic | 4 s | 0 s | 6 s | 0 s |

- The choir sings on the exhale. During the inhale the drone thins to a
  floor that the other singers carry ("chain breathing").
- The envelope never builds into a hit.

## (d) Passions never get sacred sounds, and they are stilled by silence

**Rule.** Antagonists are the passions: the eight logismoi of Evagrius
(gluttony, lust, avarice, sorrow, anger, acedia, vainglory, pride).
They never get:

- bells
- ison
- chant formants
- any sacred timbre

Their sound is **dissonant and unresolved**: tritone and minor-second
clusters, a buzzy timbre, beating, a pitch that sags and never lands.
A passion is **not defeated by a sacred-sound "weapon"**, such as a bell
blast or a prayer "beam". It is stilled by **hesychia**: the player
stops, attends and keeps silence, and the dissonance fades out
*unresolved*.

**Why.** In the ascetic teaching (Evagrius, Praktikos; Hesychius of
Sinai, "On Watchfulness", in the Philokalia) passions are overcome by
watchfulness (nepsis), stillness and grace. Force does not overcome
them. Giving a passion a bell makes the demonic sound holy. Letting a
bell kill a passion makes the sacred a weapon, which is rule (c) again.
Resolving the cluster into a consonance would suggest that the passion
was "harmonised" or integrated. The tradition speaks instead of its
being cut off and falling silent.

**In code.**

- `passionCluster()`: odd harmonics only (square-like buzz), no vowel
  formants and no bell ratios.
- Each passion's cluster includes a tritone: 0/1/6, 0/6/7, 0/6/11 and
  so on, in semitones.
- The pitch drifts 2 to 3 % flat.
- The fade-out happens while the cluster is still dissonant.
- The cue to play when a passion is overcome is `hesychia`, not a bell.

## (e) Silence (hesychia) is a sound state with meaning

**Rule.** Silence is designed and not a gap. `hesychia` is the room tone
of a stone church, around -60 dBFS. Real stillness is never digital
zero, and digital zero on a headset sounds like a fault. The game enters
hesychia deliberately:

- after a passion is stilled
- before an apophatic gate
- during inner prayer

It must not be filled with "background music" to keep the player
entertained.

**Why.** Hesychia (ἡσυχία) is the name of the whole tradition that the
game's Elder Sergius follows: stillness of body and mind as the place
where prayer of the heart lives (St Gregory Palamas, Triads). The saying
"silence is the mystery of the age to come" is commonly attributed to
St Isaac the Syrian. If silence is treated as absence of content, the
game cannot teach the thing its gates lead to.

**In code.** The `hesychia` (alias `silence`) recipe renders lowpassed
noise normalised to a peak of 0.001, which gives an RMS of about
2.5e-4. It plays on the ambience layer.

## (f) No EDM and no meaningless synth

**Rule.** The following are forbidden:

- EDM idioms: drops, sidechain pumping, risers, supersaws, four-on-the-
  floor
- decorative synth pads
- "whoosh" transitions with no meaning

Every sound has a stated meaning, kept in `SEMANTIC_CUES.meaning` and in
the synth's `describe()`.

**Why.** The constitution (section B) forbids "EDM, синтезаторные звуки
без смысла" and "фоновая музыка для затычки". A synthesiser is used here
only as a *model* of real acoustic things: a bronze bell, a wooden
board, a voice, wind, water, a sonar echo. It is never used for a
synthetic aesthetic of its own.

**In code.** Every recipe models a physical source:

- bell: modal partials from ch. 12
- semantron: modes of a free wooden beam, 1 : 2.756 : 5.404 : 8.933
  (Euler-Bernoulli beam theory)
- voice: formant-weighted harmonics
- wind and water: filtered noise
- sonar: a ping and its lake echoes

## (g) The apophatic gate is near-silence

**Rule.** Gate 6 (Apophatic) has no melody, chord or choir. It gets
near-silence and at most one far remnant of sound.

**Why.** Apophatic theology knows God by negation, "in the brilliant
darkness of a hidden silence" (Pseudo-Dionysius, *Mystical Theology*
1, a widely quoted rendering). Music that "depicts" the vision would
contradict what the gate teaches. The last sound left is the hum of the
great bell, the partial that ch. 12 says outlives all others. It is
what remains when every word has fallen away.

**In code.** `apophatic_void` is room tone plus one hum partial of the
благовестник at about -34 dBFS (peak 0.02) that fades over about 20 s,
in a 30 s loop.

## (h) Church Slavonic and Greek texts are not mangled

**Rule.** Sacred texts are never:

- reversed
- granular-scrambled
- pitch-warped for "demonic" or "magic" effect
- vocoded
- time-stretched into drones
- chopped rhythmically

When a text is heard, it is heard whole and intelligible, spoken or
chanted by a human voice, in its own language and with correct stress.
Passions never speak sacred text.

**Why.** Canon 75 of the Quinisext Council (in Trullo, 692) asks
chanters to sing without disorderly cries, without forcing the voice,
and without adding anything unfitting to the Church. The text of prayer
is the Church's word and not raw material. Distorting it for an effect
is mockery, whatever the intent.

**In code.** The synth has no text-to-speech and no granular engine. All
vocal cues are wordless. Voice lines stay recordings. When a voice
line's file is missing, it stays **silent** on purpose: the manager
does not substitute a synthesized voice for words.

---

## Supporting rules

- **(i) No chance.** The constitution forbids randomness. Every noise,
  every stroke-strength variation and every bell's detuning comes from
  Mulberry32 seeded by an FNV-1a hash of the cue or bell name. The same
  cue renders bit-identically in Chromium and in Node. The checksums
  were verified to match.
- **(j) Bells sound the same everywhere.** A bell's voice is seeded by
  the bell's name and not by the cue. The благовестник in
  `monastery_bells` is the same bell as in `perebor`.
- **(k) Pitch follows FORM.** High, rising voices mean ascent (Wisdom).
  Low voices with октавист mean rootedness (Constitution). This
  continues the audio manager's earlier convention.
- **(l) Spatial truth.** Bells come from the belfry and NPC voices from
  the NPC (HRTF in the manager). Hesychia has no direction.

## Checklist for any new sound or recording

1. Which meaning (a `SEMANTIC_CUES` entry) does it carry? If there is
   none, it does not ship.
2. Is it a bell? Then which Typikon order is it, and is that order's
   meaning true at this moment in the game?
3. Does it put an instrument under chant, a sacred timbre on a passion,
   or the Name in a mechanic? If so, reject it.
4. Is silence the right answer here? It often is.
