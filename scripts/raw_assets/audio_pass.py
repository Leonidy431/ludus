"""Audio pass: sounds from the 99 repos as spectral references only.

Operator, 2026-09-30: "добавь из 99 репо 299 звуков которые нам подходят
по трем параметрам. гит проходом."

CLAUDE.md TABOO 0.35 rule 8 says that audio from the 99 repos serves
only as a spectral reference (envelope, T60, impulse response) and is
never a sample in the game.  So this pass "adds" sounds as measured
profiles: it writes text (a table, a JSON of reference profiles, the
props register rows and a contact sheet of spectrograms) and never an
audio file inside the repository, godot/ or public/.

The three parameters, each scored 0-10 in code and deterministic:

  ПРАВО     the licence: the repository licence, overridden by a
            per-file licence hint (attributions.yml, copyrights.csv,
            a Debian copyright file, CREDITS tables) when one exists.
            NC or ND terms and repositories without a licence exclude.
  СМЫСЛ     the fit to a neutral sound slot of the game (ROV, lake,
            obitel workshop, road) by path words.  Sacred and dogma
            words, music, reward dings, voices, combat and hostile
            creatures are excluded before any slot is scored.
  АКУСТИКА  measured from the decoded file: sample rate, duration,
            clipping, noise floor, and the reference triad of rule 8:
            amplitude envelope, T60 by Schroeder backward integration,
            spectral centroid and a coarse decay profile.

A sound joins the honest pool only when all three scores are at least
PASS_SCORE.  Selection takes up to K in two tiers: tier 1 keeps the
caps of the task (per source folder, per repository, a minimum per
slot); tier 2 fills up to K only under TABOO 0.07 item 4 (at most two
states of one thing).  If fewer than K pass honestly, the real number
is reported and nothing is padded (TABOO 0.07).

Bytes are fetched only for candidates that passed the path and
licence filters, one batched fetch per blobless clone, into a cache
outside the repository (/home/user/raw-audio by default).

Usage:
    python3 scripts/raw_assets/audio_pass.py --index /home/user/raw-repos \
        --cache /home/user/raw-audio --write
"""

import argparse
import datetime
import fnmatch
import hashlib
import json
import math
import re
import subprocess
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path, PurePosixPath

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from osint_cycle import DOGMA_STOP, SACRED  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PASS_ID = 'audio-299-2026-09-30'
DEFICIT_ID = 'DEF-027'
K = 299
PASS_SCORE = 5
FOLDER_CAP = 3
REPO_CAP = 40
SLOT_MIN = 3
# TABOO 0.07 item 4: no more than two states of one thing.
THING_CAP = 2
# The second tier opens only when the first tier (the caps of the task)
# leaves fewer than K although the honest pool holds more; see select().
# It lifts the folder and repository caps (10 ** 6 = no cap) and keeps
# only the rule of TABOO 0.07: at most two states of one thing.
TIER2_FOLDER_CAP = 10 ** 6
TIER2_REPO_CAP = 10 ** 6
SHEET_SAMPLE = 48
# Bump when the measurement changes, so cached profiles are redone.
MEASURE_VERSION = 4

DECODABLE = {'.ogg', '.wav', '.mp3', '.flac', '.opus'}
AUDIO_EXT = DECODABLE | {'.mid', '.midi', '.it', '.xm', '.mod', '.s3m',
                         '.spc'}

OUT_TABLE = ROOT / 'docs' / 'RAW_AUDIO_299_2026-09-30.md'
OUT_REFS = ROOT / 'docs' / 'RAW_AUDIO_REFERENCES.json'
OUT_PROPS = ROOT / 'docs' / 'RAW_AUDIO_PROPS.json'
OUT_SHEET = ROOT / 'docs' / 'audit' / '2026-09-30' / \
    'raw-audio-299-spectra.png'
NOTICES = ROOT / 'THIRD_PARTY_NOTICES.md'
CURSOR = ROOT / 'docs' / 'RAW_OSINT_CURSOR.json'
# Everything this pass writes inside the repository is text or one PNG;
# the test suite checks that no audio extension ever appears here.
OUTPUTS = (OUT_TABLE, OUT_REFS, OUT_PROPS, OUT_SHEET, NOTICES, CURSOR)


# --- Slots -------------------------------------------------------------

# Neutral sound slots of the Ludus sound design.  "strong" words name
# the thing itself; "weak" words only suggest it.  A trailing * is a
# prefix match; other words match whole path tokens (with plural s/es).
# "use" names the cue of the headset build that may read the profile.
SLOTS = {
    'rov.motor': dict(
        place='ROV', use='dive_synth.gd HUM (thrusters), event_servo',
        strong=['motor*', 'servo*', 'thruster*', 'engine*', 'pump*',
                'turbine*', 'generator*', 'hydraulic*', 'drill*', 'fan',
                'compressor*', 'propeller*', 'machine*', 'hum', 'humming',
                'conveyor*', 'combust*'],
        weak=['whir*', 'buzz*', 'mechan*',
              'gear*', 'electric*', 'drone', 'spin*', 'rotor*']),
    'rov.sonar': dict(
        place='ROV', use='dive_synth.gd PING and ECHO (t = 2d/c)',
        strong=['sonar*', 'ping*', 'radar*', 'beep*', 'blip*', 'bleep*',
                'scan*', 'echo*'],
        weak=['signal*', 'geiger*', 'detector*', 'sweep*', 'boop*',
              'pulse*']),
    'rov.hull': dict(
        place='ROV', use='hull creak under pressure (Atlas node 63)',
        strong=['hull*', 'clank*', 'clang*', 'metal*', 'steel*', 'iron*',
                'pipe*', 'valve*', 'hatch', 'airlock*', 'pressure*'],
        weak=['hiss*', 'latch*', 'vent*', 'tank*', 'rivet*']),
    'rov.bubbles': dict(
        place='ROV', use='bubble cadence (TABOO 0.35 rule 19)',
        strong=['bubble*', 'bubbl*', 'gurgl*', 'underwater*', 'submerg*',
                'blub*'],
        weak=['fizz*', 'foam*', 'boil*']),
    'rov.console': dict(
        place='ROV', use='dive_synth.gd event_click (cockpit switches)',
        strong=['click*', 'switch*', 'button*', 'toggle*', 'keyboard*',
                'keypress*', 'typing', 'relay*', 'knob*', 'lever*'],
        weak=['tick*', 'tap', 'taps', 'key', 'keys', 'ui', 'select*',
              'hover*', 'interface*', 'cursor*', 'menu']),
    'rov.tether': dict(
        place='ROV', use='tether and winch (Atlas nodes 2, 81)',
        strong=['rope*', 'cable*', 'chain*', 'winch*', 'pulley*', 'reel*',
                'tether*', 'cord*'],
        weak=['string*', 'wire*', 'strain*', 'tension*']),
    'lake.water': dict(
        place='lake', use='surface and shore water, room tone of the lake',
        strong=['water*', 'wave*', 'lake*', 'sea', 'ocean*', 'shore*',
                'surf', 'river*', 'stream*', 'drip*', 'puddle*', 'fluid*',
                'liquid*', 'pour*', 'slosh*', 'fountain*', 'brook*',
                'tide*', 'harbor*', 'harbour*', 'pier', 'drain*'],
        weak=['flow*', 'drop', 'droplet*', 'spill*', 'wet*']),
    'lake.splash': dict(
        place='lake', use='dive_synth.gd event_take, fish at the lens',
        strong=['splash*', 'plop*', 'fish*', 'swim*', 'paddl*', 'oar*',
                'rowing'],
        weak=['boat*', 'dive', 'diving']),
    'lake.rain': dict(
        place='lake', use='weather over the lake',
        strong=['rain*', 'thunder*', 'storm*', 'drizzl*', 'hail*'],
        weak=['weather*', 'cloud*']),
    'lake.wind': dict(
        place='lake', use='shore and road wind',
        strong=['wind', 'windy', 'gust*', 'breez*', 'blizzard*',
                'snowstorm*', 'sandstorm*', 'windstorm*', 'whoosh*',
                'swoosh*'],
        weak=['air', 'gale*', 'draft']),
    'lake.birds': dict(
        place='lake', use='shore birds, eagle and pigeons (Atlas 45, 70)',
        strong=['bird*', 'gull*', 'seagull*', 'crow', 'raven*', 'owl',
                'sparrow*', 'chirp*', 'tweet*', 'duck*', 'goose', 'geese',
                'swan*', 'heron*', 'hawk*', 'eagle*', 'pigeon*', 'dove',
                'songbird*', 'cuckoo*', 'woodpecker*', 'finch*',
                'parrot*'],
        weak=['wing*', 'flap*', 'flutter*', 'feather*', 'caw*', 'coo',
              'quack*', 'peck*']),
    'lake.insects': dict(
        place='lake', use='night shore: crickets, frogs',
        strong=['insect*', 'cricket*', 'cicada*', 'bee', 'fly', 'flies',
                'mosquito*', 'frog*', 'toad*', 'grasshopper*', 'bug'],
        weak=['swarm*', 'hive*', 'croak*']),
    'workshop.wood': dict(
        place='obitel workshop', use='wood and birch-bark creak (node 56)',
        strong=['wood*', 'plank', 'log', 'timber*', 'chop*', 'axe', 'saw',
                'sawing', 'sawmill*', 'carpent*', 'lumber*', 'tree*',
                'branch*', 'twig*', 'crate*', 'barrel*', 'creak*',
                'blackwood*'],
        weak=['stick*', 'box', 'bamboo*']),
    'workshop.stone': dict(
        place='obitel workshop', use='millstone, rockfall (Atlas 23, 27)',
        strong=['stone*', 'rock*', 'gravel*', 'pebbl*', 'boulder*',
                'rubble*', 'dig', 'digging', 'pickaxe*', 'mining', 'mine',
                'quarry*', 'brick*', 'mason*', 'grindstone*', 'millstone*',
                'crumbl*', 'rockfall*', 'avalanche*', 'landslide*',
                'cave*', 'mill', 'pottery*', 'potter', 'crunch*', 'grind',
                'grinding'],
        weak=['dirt', 'sand', 'mud', 'earth*', 'clay*', 'crush*',
              'scrape*', 'collapse*', 'soil*']),
    'workshop.forge': dict(
        place='obitel workshop', use='smithy hammer rhythm (Atlas 16, 54)',
        strong=['anvil*', 'hammer*', 'smith*', 'blacksmith*', 'forge',
                'forging', 'chisel*', 'tongs', 'whetstone*', 'sharpen*',
                'grinder*', 'metalwork*', 'tool', 'wrench*',
                'screwdriver*', 'weld*', 'toolbox*', 'crowbar*',
                'ratchet*', 'scissors', 'wirecutter*', 'wirebrush*',
                'smelt*'],
        weak=['clink*', 'tink*', 'workshop*', 'craft*', 'construct*',
              'repair*']),
    'workshop.hearth': dict(
        place='obitel workshop', use='hearth and torch, 1900-2500 K class',
        strong=['fire', 'fireplace*', 'campfire*', 'bonfire*', 'hearth*',
                'flame*', 'crackl*', 'ember*', 'torch*', 'stove*', 'oven*',
                'burn', 'burning', 'match', 'sizzl*'],
        weak=['kettle*', 'steam*', 'lighter*',
              'ignit*', 'heat*', 'smoke*']),
    'workshop.scroll': dict(
        place='obitel workshop', use='quill on parchment (Atlas 64)',
        strong=['paper*', 'page*', 'book*', 'scroll*', 'parchment*',
                'quill*', 'pen', 'pencil*', 'writ*', 'scribbl*', 'ink',
                'letter*', 'envelope*', 'stamp*', 'map', 'read',
                'reading'],
        weak=['flip*', 'fold*', 'sheet*']),
    'workshop.cloth': dict(
        place='obitel workshop', use='linen, leather and bags',
        strong=['cloth*', 'fabric*', 'rustl*', 'cloak*', 'leather*', 'bag',
                'sack*', 'backpack*', 'linen*', 'wool*', 'canvas*', 'tent*',
                'zip', 'zipper*', 'velcro*', 'equip*', 'unequip*',
                'weav*', 'buckl*'],
        weak=['belt*', 'pouch*', 'drape*', 'curtain*', 'blanket*']),
    'workshop.door': dict(
        place='obitel workshop', use='wooden doors, lids, chests',
        strong=['door*', 'hinge*', 'drawer*', 'lid', 'chest', 'cabinet*',
                'locker*', 'shutter*', 'gate', 'knock*'],
        weak=['open*', 'close*', 'shut*', 'lock']),
    'road.footsteps': dict(
        place='road', use='caravan road and cell floors',
        strong=['footstep*', 'step', 'walk*', 'foot', 'feet', 'stomp*',
                'shoe*', 'boot', 'stride*', 'sneak*', 'tread*',
                'trampl*'],
        weak=['grass*', 'snow*', 'jump*', 'move*', 'movement*']),
    'road.animals': dict(
        place='road', use='horses, camels, sheep of the shepherd (node 33)',
        strong=['horse*', 'hoof*', 'hooves', 'gallop*', 'neigh*',
                'whinny*', 'camel*', 'donkey*', 'mule*', 'sheep*', 'goat*',
                'cow', 'cattle*', 'ox', 'oxen', 'yak*', 'dog', 'bark',
                'barking', 'cat', 'meow*', 'pig', 'chicken*', 'rooster*',
                'hen', 'animal*', 'livestock*', 'graz*', 'bleat*', 'moo',
                'wolf*', 'deer*', 'bear', 'farm'],
        weak=['paw*', 'sniff*', 'snort*', 'purr*']),
    'road.caravan': dict(
        place='road', use='carts and harness of the caravan road',
        strong=['cart*', 'wagon*', 'wheel*', 'carriage*', 'axle*',
                'caravan*', 'saddle*', 'harness*', 'rein', 'road*',
                'track'],
        weak=['roll*', 'rattle*', 'travel*']),
    'road.breath': dict(
        place='road', use='timbre only; timing stays with hesychasm module',
        strong=['breath*', 'inhale*', 'exhale*', 'pant', 'panting', 'huff*',
                'respirat*'],
        weak=['blow', 'blowing', 'puff*']),
}


# --- Exclusions --------------------------------------------------------

def _w(word):
    """A whole-word pattern in a lower-cased path: letters must not
    touch it, while digits, '_', '-', '.' and '/' separate words."""
    return r'(?<![a-z])' + word + r'(?![a-z])'


def _any(*parts):
    return re.compile('|'.join(parts))


# Sacred sound never comes from raw material (TABOO 0.2, 0.35 rules 5-6,
# 9-10): bells, chant, choir, organ and prayer, and magic, cult and
# summoning.  osint_cycle.SACRED and DOGMA_STOP are applied as well, so
# the audio pass refuses at least everything the image runner refuses.
AUDIO_SACRED = _any(
    'chime', 'choir', 'chant', r'organ(?!ic|is|iz)', 'hymn', 'pray',
    'liturg', 'psalm', 'kyrie', _w('amen'), 'allelu', 'hallelu', 'heaven',
    'divine', 'bless', 'spirit', _w('souls?'), 'miracle', 'resurrect',
    'sanctif', 'cathedral', 'chapel', 'abbey', 'monaster', 'mosque',
    'minaret', 'muezzin', 'buddh', 'tibet', 'mantra', r'singing.?bowl',
    _w('gongs?'), 'sacred', 'ritual', _w('cults?'), 'clockcult', 'cosmic',
    _w('spells?'), 'healspell', 'magic', 'summon', _w('curses?'),
    _w('hex'), 'ghost', 'haunt', 'necro', 'demon', 'devil', _w('hell'),
    'hellfire', 'wizard', 'witch', 'voodoo', 'exorc', _w('gods?'),
    'goddess', 'deity', 'oracle', 'shaman', 'totem', r'heal(?!th)',
    'sacrific', _w('mana'), 'cerberus', 'narsie', 'ratvar', 'desecrat',
    _w('tombs?'))

MUSIC = _any(
    _w('music'), _w('musics'), 'song', _w('themes?'), _w('bgm'), _w('ost'),
    'soundtrack', _w('tracks?'), 'jingle', 'fanfare', 'melod', 'jukebox',
    _w('lobby'), 'anthem', _w('tunes?'), 'instrument', 'piano', 'guitar',
    _w('harp'), 'violin', 'flute', _w('lute'), 'trumpet', 'ringtone',
    _w('notes?'), 'chord', 'arpegg', 'stinger', 'midi', _w('title'),
    _w('credits'), 'orchestra', 'accordion', 'xylophone', 'marimba',
    'synthesizer', _w('drums?'), 'drumroll', 'bagpipe', 'harmonica',
    'kazoo', 'banjo', _w('sax'), 'tuba', 'cello', 'ocarina',
    r'music.?box', 'cymbal', 'glockenspiel', 'sting', _w('ring'),
    'ringing')

# UI sounds serve only as instrument sounds, never as reward dings
# (SOUND_THEOLOGY_RULES (b); TABOO 0.35 rule 16: no currency or prize).
REWARD = _any(
    _w('coins?'), 'gold', 'money', _w('cash'), 'reward', r'level.?up',
    'achievement', r'power.?up', _w('bonus'), _w('prize'), 'jackpot',
    _w('win'), _w('wins'), _w('winner'), 'victory', _w('purchase'),
    _w('buy'), _w('sell'), _w('ding'), 'treasure', _w('loot'),
    _w('score'), _w('points?'), 'success', _w('complete'), 'arcade')

# Cards, dice and chips are the table of chance (TABOO 0.35 rule 15: no
# randomness in rewards), and card-game phase cues ("end_step",
# "green_land") are signals of a rule set, not the sound of a thing.
CHANCE = _any(
    _w('cards?'), 'card_', r'card(?=[a-z])', _w('deck'), _w('dice'),
    r'(?<![a-z])chips?(?![a-z])', 'casino', 'poker', 'roulette',
    'shuffle', 'mulligan', 'untap', 'upkeep', 'sorcery', 'enchant',
    'planeswalker', r'(end|draw)_?step', r'_land(?![a-z])')

# Clown horns, toy squeaks and jokes are no reference for matter.
TOY = _any('clown', 'jester', _w('toys?'), 'squeak', _w('honk'),
           'bikehorn', 'haha', 'prank', 'wawa')

# Voices are people and creatures, not matter: they are no reference
# for a neutral slot, and a real person's voice is personal data
# (TABOO 0.35 rule 21).
VOICE = _any(
    _w('voices?'), _w('vox'), 'speech', _w('talk'), _w('talking'),
    _w('say'), _w('speak'), 'scream', _w('shout'), _w('yell'),
    _w('laugh'), 'laughing', _w('cry'), _w('crying'), _w('sob'), 'cough',
    'sneeze', 'grunt', _w('moan'), 'groan', _w('gasps?'), 'emote',
    'vocal', 'dialog', 'narrat', 'announce', _w('kiss'), 'burp', 'fart',
    'hiccup', 'whimper', 'giggle', _w('sing'), 'singing', 'yawn', 'snore',
    'laugh',
    _w('sigh'), 'hello', 'greeting', 'goodbye', _w('keeper'), 'humanoid',
    _w('human'), _w('male'), _w('female'))

# The game has no combat (Atlas node 60), so weapons and wounds are no
# reference for anything it plays.
COMBAT = _any(
    'weapon', _w('guns?'), 'gunshot', _w('shoot'), 'shooting', _w('shot'),
    _w('shots'), 'rifle', 'pistol', 'shotgun', 'laser', 'blaster',
    'cannon', 'missile', 'rocket', 'torpedo', _w('bombs?'), 'grenade',
    'explo', _w('blast'), 'bullet', _w('ammo'), 'reload', _w('swords?'),
    _w('blade'), _w('knife'), _w('dagger'), _w('attacks?'), _w('punch'),
    _w('kick'), _w('slash'), _w('stab'), _w('kill'), _w('die'),
    _w('dies'), 'dying', _w('death'), _w('dead'), 'blood', _w('gore'),
    'combat', 'battle', _w('war'), _w('fight'), 'melee', _w('arrows?'),
    _w('bow'), 'crossbow', _w('spear'), _w('mace'), _w('flail'),
    _w('hurt'), _w('pain'), _w('damage'), 'injur', _w('gib'),
    _w('hits?'), 'turret', 'artillery', 'flamethrower', 'plasma',
    _w('mecha'), 'swordblock', 'gun', 'shot', r'mech(?!an)',
    r'mine.?deploy', _w('fists?'), _w('miss'), _w('pew'), 'taser',
    _w('stun'), 'baton', 'handcuff', 'flashbang', 'meat', 'flesh',
    r'tank(move|shot)', 'landmine', 'shield',
    # Weapon outfits of endless-sky and wesnoth named after weather or
    # fire: the path alone reads as rain or a hearth, the game does not.
    'firestorm', r'ion.?(rain|torch|cannon)', 'thunderhead',
    r'fate.?fire', 'plankton', 'thunderstick', 'sidewinder', 'meteor',
    'sheath', 'cavalry', 'warhorn', 'wardrum')

HOSTILE = _any(
    'monster', 'zombie', _w('xeno'), 'xenoborg', 'alien', _w('beast'),
    _w('slime'), _w('mobs?'), 'enem', _w('boss'), _w('orcs?'), 'goblin',
    'troll', 'dragon', 'undead', 'skeleton', _w('lich'), 'ghoul',
    'vampire', 'werewolf', 'changeling', _w('antag'), 'syndicate',
    _w('nuke'), 'spider', 'arachnid', 'spawn')

# Order matters only for the reason recorded; a path is refused by the
# first family it touches.
PATH_FILTERS = (
    ('dogma-stop-list', DOGMA_STOP),
    ('sacred-never-raw', SACRED),
    ('sacred-sound', AUDIO_SACRED),
    ('music', MUSIC),
    ('reward-ding', REWARD),
    ('chance-or-card-game', CHANCE),
    ('toy-or-joke', TOY),
    ('voice', VOICE),
    ('combat', COMBAT),
    ('hostile', HOSTILE),
)

# Short manual review of names the families cannot read, each with its
# reason; deterministic like the families (TABOO 0.07: open criteria).
_ROCK_LOOP = 'a test music loop ("rock"), not stone'
_SS14 = 'space-wizards__space-station-14'
_MGA = 'Tests/Assets/Audio/'
REVIEW_DROPS = {
    (_SS14, 'Resources/Audio/Items/Medical/paper_centrifuge.ogg'):
        'a centrifuge, not paper',
    (_SS14, 'Resources/Audio/Effects/Fluids/vacuum-cleaner-fast.ogg'):
        'a vacuum cleaner, not water',
}
REVIEW_DROPS.update({
    ('MonoGame__MonoGame', _MGA + name): _ROCK_LOOP
    for name in ('rock_loop_stereo.mp3', 'rock_loop_stereo.ogg',
                 'rock_loop_mono.wav', 'rock_loop_stereo.wav',
                 'rock_loop_stereo_44hz_8bit.wav',
                 'rock_loop_stereo_44hz_adpcm_ms.wav')})


def attack_with_miss(path, siblings):
    """True when the folder also holds '<name>-miss': that pairs an
    attack with its miss (wesnoth "torch", "ink", "hatchet")."""
    stem = PurePosixPath(path).stem.lower()
    return any(stem + sep + 'miss' in siblings for sep in ('-', '_', ''))


def tokens(text):
    """Split a path into lower-case words (camelCase and digits split)."""
    text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)
    text = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', text)
    return [w for w in re.split(r'[^a-zA-Z]+', text.lower()) if w]


def keyword_hit(keyword, token):
    """Whole-token match with plural endings, or a prefix match for *.

    A starred stem of six letters or more also matches inside a
    compound token ("onefootstep"); five letters were too few, since
    "screwdriver" and "massdriver" both hide a "river"."""
    if keyword.endswith('*'):
        stem = keyword[:-1]
        return token.startswith(stem) or (len(stem) >= 6 and stem in token)
    return token in (keyword, keyword + 's', keyword + 'es')


def refusal(path):
    """First exclusion family a path touches, or None."""
    low = path.lower()
    for reason, pattern in PATH_FILTERS:
        if pattern.search(low):
            return reason
    return None


# Folder names that sort a whole game's sounds into broad bins say
# nothing of the thing: space-station-14 files every machine beep,
# printer and vending tune under Machines/, and none of them is a motor.
CATEGORY_FOLDERS = {'machines', 'machine'}


def slot_of(path, noise=()):
    """Best neutral slot of a path: (slot, meaning score, keywords).

    Evidence weighs by where the word stands.  A strong word weighs 2
    in the file name, 1 in the file's own folder and 0.5 higher up; a
    weak word weighs 0.75 in the name and 0.25 in its own folder.  Words
    of the repository name are noise (Card-Forge keeps its files under
    forge-gui/, which is not a forge).  Score = min(10, int(2 + 3 w)):
    a strong word in the name gives 8, in the own folder 5, a weak word
    alone gives 4 and fails, as does a strong word only far up the tree
    (defold keeps test sounds under engine/, which is not an engine).
    """
    parts = PurePosixPath(path)
    name_tokens = set(tokens(parts.stem))
    folders = [set(tokens(f)) - set(noise) - CATEGORY_FOLDERS
               for f in parts.parts[:-1]]
    own = folders[-1] if folders else set()
    upper = set().union(*folders[:-1]) if len(folders) > 1 else set()
    best = (None, 0.0, [])
    for slot, spec in SLOTS.items():
        weight, found = 0.0, []
        for words, w_name, w_own, w_up in (
                (spec['strong'], 2.0, 1.0, 0.5),
                (spec['weak'], 0.75, 0.25, 0.0)):
            for kw in words:
                if any(keyword_hit(kw, t) for t in name_tokens):
                    weight += w_name
                elif any(keyword_hit(kw, t) for t in own):
                    weight += w_own
                elif w_up and any(keyword_hit(kw, t) for t in upper):
                    weight += w_up
                else:
                    continue
                found.append(kw.rstrip('*'))
        if weight > best[1]:
            best = (slot, weight, found)
    slot, weight, found = best
    if slot is None:
        return None, 0, []
    return slot, min(10, int(2 + 3 * weight)), sorted(set(found))


# --- Licence -----------------------------------------------------------

# Non-commercial and no-derivatives terms of Creative Commons.  The GPL
# text itself says "noncommercially", so the pattern names CC terms.
NC_ND = re.compile(
    r'attribution-noncommercial|attribution-noderiv|noderivatives|'
    r'cc[- ]by[- ]nc|cc[- ]by[- ]nd|(?<![a-z])by-n[cd](?![a-z])|'
    r'creativecommons\.org/licenses/by-n[cd]|no derivative works',
    re.IGNORECASE)

LICENCE_CLASSES = (
    ('PD', r'cc0|public[- ]domain|unlicense'),
    ('CC-BY-SA', r'attribution-sharealike|cc[- ]by[- ]sa|'
                 r'(?<![a-z])by-sa(?![a-z])'),
    ('CC-BY', r'cc[- ]by(?![- ]?(sa|nc|nd))|'
              r'creative commons attribution(?![- ](share|non|no))|'
              r'oga-by'),
    ('AGPL', r'gnu affero|agpl'),
    ('LGPL', r'gnu lesser|lgpl'),
    ('GPL', r'gnu general public|gnu gpl|(?<![a-z])gpl'),
    ('MPL', r'mozilla public'),
    ('Ms-PL', r'microsoft public license'),
    ('Apache', r'apache license|(?<![a-z])apache'),
    ('MIT', r'permission is hereby granted|(?<![a-z])mit(?![a-z])'),
    ('BSD', r'redistribution and use in source|(?<![a-z])bsd'),
    ('Zlib', r'provided [\'"]as-is[\'"]|(?<![a-z])zlib'),
    ('Artistic', r'artistic license'),
    ('Custom', r'defold license'),
)
LICENCE_RE = [(cls, re.compile(p, re.IGNORECASE))
              for cls, p in LICENCE_CLASSES]

# Base ПРАВО score of each class (TABOO 0.07 criterion "правда" for the
# lawyer: free terms rank above share-alike, custom terms need review).
LICENCE_BASE = {'PD': 10, 'MIT': 9, 'BSD': 9, 'Zlib': 9, 'Apache': 9,
                'Ms-PL': 8, 'MPL': 8, 'CC-BY': 7, 'Artistic': 6, 'LGPL': 6,
                'GPL': 5, 'CC-BY-SA': 5, 'Custom': 5, 'AGPL': 4,
                'UNKNOWN': 3}
SHARE_ALIKE = {'GPL', 'LGPL', 'AGPL', 'CC-BY-SA', 'MPL'}
CODE_LICENCES = {'MIT', 'BSD', 'Zlib', 'Apache', 'Ms-PL', 'MPL'}


def classify_short(text):
    """Class of a short licence string (a hint); NC or ND wins."""
    if NC_ND.search(text):
        return 'NC-ND'
    for cls, pattern in LICENCE_RE:
        if pattern.search(text):
            return cls
    return None


def classify_long(text):
    """Class of a whole licence file: the earliest named licence wins,
    and CC non-commercial or no-derivatives terms anywhere flag it."""
    first = None
    for cls, pattern in LICENCE_RE:
        found = pattern.search(text)
        if found and (first is None or found.start() < first[1]):
            first = (cls, found.start())
    return (first[0] if first else 'UNKNOWN'), bool(NC_ND.search(text))


def right_score(repo_class, repo_nc, hint, repo_mentions_assets):
    """ПРАВО 0-10 as (score, reason, class); reason set = excluded."""
    if hint:
        cls = classify_short(hint)
        if cls == 'NC-ND':
            return None, 'licence-nc-nd', cls
        if cls is None:
            cls = 'UNKNOWN'
        # A per-file licence is documented provenance: one point more.
        return min(10, LICENCE_BASE[cls] + 1), None, cls
    if repo_class is None:
        return None, 'no-licence-repo', None
    if repo_nc:
        return None, 'licence-nc-nd', 'NC-ND'
    score = LICENCE_BASE.get(repo_class, 3)
    if repo_class in CODE_LICENCES and not repo_mentions_assets:
        # A code licence says nothing sure about sound assets.
        score -= 2
    return score, None, repo_class


# Per-file licence hints ------------------------------------------------

HINT_NAME = re.compile(
    r'(^|/)((attributions?|credits|copying|licen[cs]e|authors|copyright)'
    r'[^/]*|copyrights\.csv)$', re.IGNORECASE)


def hints_attributions_yml(folder, text):
    """space-station-14 style: '- files: [...]' blocks with 'license:'."""
    out = {}
    for block in re.split(r'\n(?=- files)', '\n' + text):
        lic = re.search(r'license:\s*"?([^"\n]+)"?', block)
        if not lic:
            continue
        head = block[:lic.start()]
        for name in re.findall(r'([\w\-.()]+\.(?:ogg|wav|mp3|flac|opus))',
                               head):
            out[f'{folder}/{name}' if folder else name] = lic.group(1)
    return out


def hints_copyrights_csv(text):
    """wesnoth style: Date,File,License,... rows with exact paths."""
    out = {}
    for line in text.splitlines()[1:]:
        cols = line.split(',')
        if len(cols) > 2 and '/' in cols[1]:
            out[cols[1].strip()] = cols[2].strip()
    return out


def hints_debian(text):
    """Debian copyright format: (glob patterns, licence) stanzas; the
    last matching stanza wins, as the format prescribes."""
    rules = []
    for stanza in re.split(r'\n\s*\n', text):
        files = re.search(r'^Files:(.*(?:\n[ \t]+.*)*)', stanza, re.M)
        lic = re.search(r'^License:\s*(.+)$', stanza, re.M)
        if files and lic:
            globs = files.group(1).split()
            rules.append((globs, lic.group(1).strip()))
    return rules


LICENCE_TOKEN = re.compile(
    r'(CC0[\w.-]*|CC[- ]BY[- ]N[CD][\w .-]*?\d\.\d|'
    r'CC[- ]BY[- ]SA[\w .-]*?\d\.\d|CC[- ]BY[- ]SA|CC[- ]BY[\w .-]*?\d\.\d|'
    r'CC[- ]BY|OGA-BY[\w .-]*|public[- ]domain|(?:GNU )?[AL]?GPL[\w .+-]*|'
    r'MIT|Apache[\w .-]*\d|(?<![A-Za-z])BY(?![A-Za-z]))', re.IGNORECASE)


def licence_token(text):
    """The licence named in a line of a credits text, as written."""
    found = LICENCE_TOKEN.search(text)
    return found.group(1).strip(' .,') if found else None


def hints_credits_table(text):
    """OpenDungeons style: section prefix, folder lines, '-> pattern'."""
    rules, prefix, folder = [], '', ''
    for line in text.splitlines():
        sec = re.match(r'^==\s+.*:\s+(\S+/)\s+==', line)
        if sec:
            prefix, folder = sec.group(1), ''
            continue
        if re.match(r'^[^\s>=-][^ ]*/\s*$', line):
            folder = line.strip().replace('\\', '/')
            continue
        item = re.match(r'^->\s+(\S+)\s+(.*)$', line)
        if item and classify_short(item.group(2)):
            rules.append((prefix + folder + item.group(1),
                          licence_token(item.group(2))
                          or classify_short(item.group(2))))
    return rules


def hints_generic(text, names):
    """Any credits or licence text: a line naming the file, with a
    licence on it or on the next two lines."""
    out = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        for name in names:
            if re.search(r'(?<![\w.-])' + re.escape(name) + r'(?![\w.-])',
                         line):
                near = ' '.join(lines[i:i + 3])
                cls = classify_short(near)
                if cls:
                    out[name] = licence_token(near) or cls
    return out


def file_hints(candidate_paths, hint_texts):
    """Map each candidate path to the licence its hint files state."""
    exact, globbed = {}, []
    for hint_path, text in sorted(hint_texts.items()):
        name = PurePosixPath(hint_path).name.lower()
        folder = str(PurePosixPath(hint_path).parent)
        folder = '' if folder == '.' else folder
        if name.startswith('attributions') and name.endswith('.yml'):
            exact.update(hints_attributions_yml(folder, text))
        elif name == 'copyrights.csv':
            exact.update(hints_copyrights_csv(text))
        elif text.startswith('Format:') and 'Files:' in text:
            globbed.append(('debian', folder, hints_debian(text)))
        elif re.search(r'^->\s', text, re.M):
            globbed.append(('credits', folder, hints_credits_table(text)))
        else:
            scope = [p for p in candidate_paths
                     if not folder or p.startswith(folder + '/')]
            names = sorted({PurePosixPath(p).name for p in scope})
            for fname, lic in hints_generic(text, names).items():
                for p in scope:
                    if PurePosixPath(p).name == fname:
                        exact.setdefault(p, lic)
    result = {}
    for path in candidate_paths:
        if path in exact:
            result[path] = (exact[path], 'per-file')
            continue
        for kind, folder, rules in globbed:
            rel = path[len(folder) + 1:] if folder else path
            if kind == 'debian':
                match = None
                for globs, lic in rules:
                    if any(fnmatch.fnmatchcase(rel, g) for g in globs):
                        match = (globs, lic)
                # "Files: *" is the whole repository, not a file hint.
                if match and match[0] != ['*']:
                    result[path] = (match[1], 'debian-copyright')
            else:
                for pattern, lic in rules:
                    if fnmatch.fnmatchcase(rel, pattern):
                        result[path] = (lic, 'credits-table')
    return result


# --- Acoustics ---------------------------------------------------------

BANDS = (125, 250, 500, 1000, 2000, 4000, 8000)


def _fit_decay(t, edc_db, top, bottom):
    """Least-squares line through the EDC between two levels in dB."""
    sel = (edc_db <= top) & (edc_db >= bottom)
    if sel.sum() < 4:
        return None
    slope, icpt = np.polyfit(t[sel], edc_db[sel], 1)
    if slope >= 0:
        return None
    pred = slope * t[sel] + icpt
    ss_res = float(((edc_db[sel] - pred) ** 2).sum())
    ss_tot = float(((edc_db[sel] - edc_db[sel].mean()) ** 2).sum()) or 1e-9
    return -60.0 / slope, 1.0 - ss_res / ss_tot


def schroeder(energy, dt, floor_rel_db):
    """T60 by Schroeder backward integration of a decay after the peak.

    energy: energy per block; dt: block length in s; floor_rel_db: the
    noise floor relative to the peak block.  The integral stops where
    the decay meets the floor (+10 dB), so noise does not lengthen T60.
    Returns a dict with t60, method (T30, T20, T10 or none), r2, EDT,
    the tail length and 12 points of the EDC in dB.
    """
    out = {'t60_s': None, 't60_method': 'none', 't60_r2': None,
           'edt_s': None, 'tail_s': 0.0, 'edc_db': []}
    if len(energy) == 0 or energy.max() <= 0:
        return out
    peak = int(np.argmax(energy))
    e = energy[peak:]
    rel = 10 * np.log10(e / e.max() + 1e-20)
    above = np.nonzero(rel > floor_rel_db + 10)[0]
    end = int(above[-1]) + 1 if len(above) else 1
    e = e[:end]
    out['tail_s'] = round(end * dt, 3)
    if end < 5:
        return out
    edc = np.cumsum(e[::-1])[::-1]
    edc_db = 10 * np.log10(edc / edc[0] + 1e-20)
    t = np.arange(end) * dt
    idx = np.linspace(0, end - 1, 12).round().astype(int)
    out['edc_db'] = [round(float(v), 1) for v in edc_db[idx]]
    edt = _fit_decay(t, edc_db, 0.0, -10.0)
    if edt:
        out['edt_s'] = round(edt[0], 3)
    for method, bottom in (('T30', -35.0), ('T20', -25.0), ('T10', -15.0)):
        if edc_db.min() <= bottom:
            fit = _fit_decay(t, edc_db, -5.0, bottom)
            if fit:
                out['t60_s'] = round(fit[0], 3)
                out['t60_method'] = method
                out['t60_r2'] = round(fit[1], 3)
            break
    return out


def envelope_points(env_db, n=16):
    """n points of the envelope in dB relative to the peak (max-pooled)."""
    parts = np.array_split(env_db, n) if len(env_db) >= n else [env_db]
    return [round(float(max(p.max(), -90.0)) * 2) / 2 for p in parts]


def stft_power(mono, sr):
    n_fft = 2048 if sr > 30000 else 1024
    hop = n_fft // 4
    if len(mono) < n_fft:
        mono = np.pad(mono, (0, n_fft - len(mono)))
    count = 1 + (len(mono) - n_fft) // hop
    idx = np.arange(n_fft)[None, :] + hop * np.arange(count)[:, None]
    frames = mono[idx] * np.hanning(n_fft)[None, :]
    power = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    return power, freqs, hop / sr


def measure(samples, sr):
    """Measure one decoded sound (float array, shape (n,) or (n, ch)).

    Returns the reference profile of TABOO 0.35 rule 8 plus the facts
    the АКУСТИКА score is built from.  Pure numpy, deterministic.
    """
    x = np.asarray(samples, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n, channels = x.shape
    prof = {'sr': int(sr), 'channels': int(channels),
            'duration_s': round(n / sr, 3)}
    peak = float(np.abs(x).max()) if n else 0.0
    prof['peak_dbfs'] = round(20 * math.log10(peak + 1e-12), 2)
    prof['clipped_pct'] = round(
        100.0 * float((np.abs(x) >= 0.999).mean()) if n else 0.0, 4)
    # A DC offset (found in some keyboard and step files) is energy at
    # 0 Hz that no ear hears; it is removed before envelope and spectrum.
    mono = (x - x.mean(axis=0)).mean(axis=1)
    frame = max(1, int(sr * 0.020))
    count = max(1, n // frame)
    rms = np.sqrt((mono[:count * frame] ** 2).reshape(count, frame)
                  .mean(axis=1) + 1e-24) if n >= frame else \
        np.array([math.sqrt(float((mono ** 2).mean()) + 1e-24)])
    rms_db = 20 * np.log10(rms)
    floor = max(float(np.percentile(rms_db, 10)), -120.0)
    top = float(rms_db.max())
    prof['noise_floor_dbfs'] = round(floor, 1)
    prof['snr_db'] = round(top - floor, 1)
    # Envelope in 2 ms blocks for attack and decay.
    blk = max(1, int(sr * 0.002))
    nb = max(1, n // blk)
    energy = (mono[:nb * blk] ** 2).reshape(nb, blk).sum(axis=1) \
        if n >= blk else np.array([float((mono ** 2).sum())])
    env = np.sqrt(energy / blk)
    p = int(np.argmax(env))
    pk = env[p] if env[p] > 0 else 1e-12
    env_db = 20 * np.log10(env / pk + 1e-12)
    start = int(np.argmax(env >= 0.1 * pk))
    a90 = start + int(np.argmax(env[start:] >= 0.9 * pk))
    prof['attack_ms'] = round((a90 - start) * blk / sr * 1000, 1)
    after = env[p:]
    d20 = np.nonzero(after <= 0.1 * pk)[0]
    d40 = np.nonzero(after <= 0.01 * pk)[0]
    prof['decay20_ms'] = round(d20[0] * blk / sr * 1000, 1) \
        if len(d20) else None
    prof['decay40_ms'] = round(d40[0] * blk / sr * 1000, 1) \
        if len(d40) else None
    prof['envelope_db'] = envelope_points(env_db)
    floor_rel = floor - 20 * math.log10(pk + 1e-12)
    prof.update(schroeder(energy, blk / sr, floor_rel))
    # Spectrum: centroid, 95 % roll-off, flatness, octave bands.
    power, freqs, hop_s = stft_power(mono, sr)
    audible = freqs >= 20.0
    power, freqs = power[:, audible], freqs[audible]
    total = power.sum(axis=0)
    tsum = float(total.sum()) or 1e-20
    prof['centroid_hz'] = round(float((freqs * total).sum() / tsum), 1)
    cum = np.cumsum(total) / tsum
    prof['rolloff95_hz'] = round(float(freqs[int(np.searchsorted(
        cum, 0.95))]) if cum[-1] > 0 else 0.0, 1)
    band = (freqs >= 100) & (freqs <= min(16000, sr / 2))
    spec = total[band] + 1e-20
    prof['flatness'] = round(float(np.exp(np.log(spec).mean())
                                   / spec.mean()), 4)
    bands, band_t60 = {}, {}
    for c in BANDS:
        lo, hi = c / math.sqrt(2), c * math.sqrt(2)
        key = str(c)
        if hi > sr / 2:
            bands[key], band_t60[key] = None, None
            continue
        sel = (freqs >= lo) & (freqs < hi)
        be = power[:, sel].sum(axis=1)
        bands[key] = round(10 * math.log10(float(be.sum()) / tsum
                                           + 1e-20), 1)
        bfloor = 10 * math.log10(
            np.percentile(be, 10) / (be.max() + 1e-20) + 1e-20)
        band_t60[key] = schroeder(be, hop_s, bfloor)['t60_s'] \
            if be.max() > 0 else None
    prof['bands_db'] = bands
    prof['band_t60_s'] = band_t60
    return prof


def is_impulsive(prof):
    """True when the sound is one blow that dies away: at most a quarter
    of its 16 envelope points lie within 10 dB of the peak, and after
    the peak it falls below -20 dB.  Only then is its T60 a decay of the
    thing (or the room); for a sustained wind, rain or hum, and for a
    train of hammer blows, the fitted "T60" is the file's fade-out."""
    env = prof['envelope_db']
    loud = sum(1 for v in env if v > -10.0)
    peak = env.index(max(env))
    return loud <= len(env) // 4 and any(v <= -20.0
                                         for v in env[peak + 1:])


def acoustic_score(prof):
    """АКУСТИКА 0-10, or (None, reason) for a hard failure."""
    if prof['sr'] < 22050:
        return None, 'sample-rate'
    if not 0.05 <= prof['duration_s'] <= 30.0:
        return None, 'duration'
    if prof['peak_dbfs'] < -60.0:
        return None, 'silent'
    clip_ok = prof['peak_dbfs'] < -0.3
    if not clip_ok and prof['clipped_pct'] >= 0.1:
        return None, 'clipping'
    score = 2 if prof['sr'] >= 44100 else 1
    score += 2 if clip_ok else 1
    score += 2 if prof['snr_db'] >= 40 else (1 if prof['snr_db'] >= 25
                                             else 0)
    if prof['attack_ms'] is not None and prof['decay20_ms'] is not None:
        score += 1
    if prof['t60_method'] in ('T20', 'T30') and \
            (prof['t60_r2'] or 0) >= 0.9:
        score += 2
    elif prof['t60_method'] == 'T10' or prof['edt_s']:
        score += 1
    if prof['rolloff95_hz'] >= 8000:
        score += 1
    return min(10, score), None


def decode(path):
    """Decode with ffmpeg to float32 at the file's own rate and layout."""
    probe = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'a:0',
         '-show_entries', 'stream=sample_rate,channels', '-of', 'json',
         str(path)], capture_output=True, text=True, timeout=60)
    streams = json.loads(probe.stdout or '{}').get('streams') or []
    if not streams:
        raise ValueError('no audio stream')
    sr, ch = int(streams[0]['sample_rate']), int(streams[0]['channels'])
    raw = subprocess.run(
        ['ffmpeg', '-v', 'error', '-i', str(path), '-t', '31', '-f',
         'f32le', '-acodec', 'pcm_f32le', '-'],
        capture_output=True, timeout=120).stdout
    data = np.frombuffer(raw, dtype='<f4')
    if ch > 1:
        data = data[:len(data) // ch * ch].reshape(-1, ch)
    if len(data) == 0:
        raise ValueError('empty decode')
    return data, sr


# --- Selection ---------------------------------------------------------

def rank_key(c):
    """Deterministic order: the weakest of the three scores first (a
    sound fits only as well as its weakest parameter), then the total,
    meaning, acoustics, right, then the sha1 of repo and path (never a
    random draw; TABOO 0.35 rule 15)."""
    s = c['scores']
    tie = hashlib.sha1(f'{c["repo"]}:{c["path"]}'.encode()).hexdigest()
    three = (s['right'], s['meaning'], s['acoustics'])
    return (-min(three), -sum(three), -s['meaning'], -s['acoustics'],
            -s['right'], tie)


# Words that name a state of a thing, not another thing: door_open and
# door_close are one door in two states, impactWood_light and _heavy one
# knock on wood (TABOO 0.07 item 4: at most two states of one thing).
STATE_WORDS = {
    'empty', 'loop', 'looped', 'start', 'end', 'done', 'on', 'off',
    'open', 'close', 'closed', 'opening', 'closing', 'small', 'large',
    'big', 'medium', 'light', 'heavy', 'fast', 'slow', 'soft', 'hard',
    'happy', 'weak', 'strong', 'short', 'long', 'ext', 'in', 'out', 'up',
    'down', 'high', 'low', 'tiny', 'mono', 'stereo', 'alt', 'var', 'v',
    'variant', 'mix', 'sub', 'quick', 'hz', 'bit', 'a', 'b', 'c', 'x'}


def thing_of(path):
    """The thing a file sounds: its folder and the words of its name
    without take numbers and state words, so grass1..grass4 are one
    thing, and so are door_open and door_close."""
    parts = PurePosixPath(path)
    words = [w for w in tokens(parts.stem) if w not in STATE_WORDS]
    return str(parts.parent), ' '.join(words) or parts.stem.lower()


def select(pool, k=K, tiers=((FOLDER_CAP, REPO_CAP),
                             (TIER2_FOLDER_CAP, TIER2_REPO_CAP)),
           slot_min=SLOT_MIN, thing_cap=THING_CAP):
    """Take up to k with diversity; return (chosen, tier of each, cut).

    Tier 1 keeps the caps of the task: a minimum per slot first, then
    rank order, at most tiers[0] per source folder and per repository.
    Tier 2 runs only if tier 1 leaves fewer than k while the honest pool
    holds more: it continues in rank order under looser folder and
    repository caps.  Both tiers keep at most thing_cap states of one
    thing (TABOO 0.07 item 4).  cut = pool members left out when fewer
    than k were chosen.
    """
    ranked = sorted(pool, key=rank_key)
    chosen, taken = [], set()
    per_folder, per_repo, per_thing = Counter(), Counter(), Counter()

    def fits(c, folder_cap, repo_cap):
        folder = (c['repo'], str(PurePosixPath(c['path']).parent))
        return (per_folder[folder] < folder_cap
                and per_repo[c['repo']] < repo_cap
                and per_thing[(c['repo'], thing_of(c['path']))]
                < thing_cap)

    def take(c, tier):
        # A copy: select() runs several times and must not mark the pool.
        chosen.append(dict(c, tier=tier))
        taken.add((c['repo'], c['path']))
        per_folder[(c['repo'], str(PurePosixPath(c['path']).parent))] += 1
        per_repo[c['repo']] += 1
        per_thing[(c['repo'], thing_of(c['path']))] += 1

    folder_cap, repo_cap = tiers[0]
    for slot in SLOTS:
        got = 0
        for c in ranked:
            if got >= slot_min or len(chosen) >= k:
                break
            if c['slot'] == slot and fits(c, folder_cap, repo_cap):
                take(c, 1)
                got += 1
    for tier, (folder_cap, repo_cap) in enumerate(tiers, 1):
        for c in ranked:
            if len(chosen) >= k:
                break
            if (c['repo'], c['path']) not in taken and \
                    fits(c, folder_cap, repo_cap):
                take(c, tier)
    chosen.sort(key=lambda c: (list(SLOTS).index(c['slot']),
                               rank_key(c)))
    cut = len(pool) - len(chosen) if len(chosen) < k else 0
    return chosen, cut


def sheet_sample(chosen, n=SHEET_SAMPLE):
    """Round-robin over slots in rank order, so every slot is seen."""
    by_slot = defaultdict(list)
    for c in sorted(chosen, key=rank_key):
        by_slot[c['slot']].append(c)
    out, depth = [], 0
    while len(out) < n and any(len(v) > depth for v in by_slot.values()):
        for slot in SLOTS:
            if len(by_slot[slot]) > depth and len(out) < n:
                out.append(by_slot[slot][depth])
        depth += 1
    return out


def cache_path(cache_root, repo, path):
    """Where a fetched file lives: always outside the repository."""
    root = Path(cache_root).resolve()
    if root == ROOT or ROOT in root.parents:
        raise ValueError(f'audio cache {root} is inside the repository')
    return root / repo / path


# --- Git ---------------------------------------------------------------

def git(clone, *args, data=None, timeout=900):
    return subprocess.run(['git', *args], cwd=clone, input=data,
                          capture_output=True, timeout=timeout, check=True)


def fetch_blobs(clone, commit, paths):
    """Fetch the blobs of paths in one batch; return {path: bytes}.

    A blobless clone would fetch each blob on its own round trip; the
    missing ones are listed without network and fetched together.
    """
    if not paths:
        return {}
    listing = git(clone, 'ls-tree', '-r', commit).stdout.decode()
    oid_of = {}
    wanted = set(paths)
    for line in listing.splitlines():
        meta, p = line.split('\t', 1)
        if p in wanted:
            oid_of[p] = meta.split()[2]
    missing = {ln[1:] for ln in git(
        clone, 'rev-list', '--objects', '--missing=print',
        '--no-object-names', commit).stdout.decode().splitlines()
        if ln.startswith('?')}
    need = sorted({oid_of[p] for p in oid_of} & missing)
    for i in range(0, len(need), 400):
        git(clone, '-c', 'fetch.negotiationAlgorithm=noop', 'fetch',
            'origin', '--no-tags', '--no-write-fetch-head',
            '--recurse-submodules=no', '--filter=blob:none', '--stdin',
            data='\n'.join(need[i:i + 400]).encode() + b'\n')
    out = {}
    for p, oid in oid_of.items():
        out[p] = git(clone, 'cat-file', 'blob', oid).stdout
    return out


# --- Pass --------------------------------------------------------------

def parent_of(path):
    """Folder of a path, '' for the repository root."""
    parent = str(PurePosixPath(path).parent)
    return '' if parent == '.' else parent


def load_index(index_root):
    for f in sorted(Path(index_root, 'index').glob('*.jsonl')):
        lines = f.read_text(encoding='utf-8').splitlines()
        header = json.loads(lines[0])['header']
        yield f.stem, header, [json.loads(ln) for ln in lines[1:]]


def repo_licence(index_root, name, header, records):
    """Class, NC flag and asset mention of the top-level licence files.

    The index header keeps only the first licence file; this reads all
    of them (Cataclysm-DDA lists a font licence first, while its game
    licence is CC-BY-SA), skipping font licences.
    """
    if not header['license_file']:
        return None, False, False, []
    tops = [r['path'] for r in records if '/' not in r['path']
            and r['path'].upper().startswith(
                ('LICENSE', 'LICENCE', 'COPYING', 'COPYRIGHT'))
            and 'FONT' not in r['path'].upper()]
    clone = Path(index_root) / 'clones' / name
    texts = fetch_blobs(clone, header['commit'], tops)
    classes, nc, assets = [], False, False
    for path in tops:
        text = texts[path].decode('utf-8', 'replace')
        register = path.lower() == 'copyrights.csv' or \
            text.startswith('Format:')
        if register:
            # A per-file register (wesnoth copyrights.csv, a Debian
            # copyright file): its head names the code licence, and its
            # NC rows bind only their own files, which the hints handle.
            text = text[:4000]
        cls, flag = classify_long(text)
        classes.append(cls)
        nc = nc or (flag and not register)
        assets = assets or bool(re.search(
            r'sound|audio|asset|artwork|data files', text, re.I))
    known = [c for c in classes if c != 'UNKNOWN']
    # A data licence file (COPYING-data) speaks for sound first.
    for path, cls in zip(tops, classes):
        if 'DATA' in path.upper() and cls != 'UNKNOWN':
            return cls, nc, True, tops
    return (known[0] if known else 'UNKNOWN'), nc, assets, tops


def run_pass(index_root, cache_root, jobs=4, log=print):
    """Build the pool, measure it and return everything main() writes."""
    stats = Counter()
    candidates, repos = [], {}
    measure_cache_file = Path(cache_root) / '_measure.json'
    cache_path(cache_root, 'x', 'y')  # refuse a cache inside the repo
    try:
        mcache = json.loads(measure_cache_file.read_text('utf-8'))
    except (OSError, ValueError):
        mcache = {}
    if mcache.get('_version') != MEASURE_VERSION:
        mcache = {'_version': MEASURE_VERSION}

    for name, header, records in load_index(index_root):
        audio = [r['path'] for r in records if r['kind'] == 'audio']
        if not audio:
            continue
        stats['index-audio'] += len(audio)
        noise = set(tokens(name.replace('__', ' ')))
        rclass, rnc, rassets, rfiles = repo_licence(index_root, name,
                                                    header, records)
        repos[name] = {'url': header['repo'], 'commit': header['commit'],
                       'class': rclass, 'nc': rnc, 'files': rfiles}
        staged = []
        siblings = defaultdict(set)
        for path in audio:
            parts = PurePosixPath(path)
            siblings[str(parts.parent)].add(parts.stem.lower())
        for path in audio:
            ext = PurePosixPath(path).suffix.lower()
            if ext not in DECODABLE:
                stats['excluded:not-decodable-format'] += 1
                continue
            if rclass is None:
                stats['excluded:no-licence-repo'] += 1
                continue
            reason = refusal(path)
            if not reason and attack_with_miss(
                    path, siblings[str(PurePosixPath(path).parent)]):
                reason = 'combat'
            if not reason and (name, path) in REVIEW_DROPS:
                reason = 'review'
            if reason:
                stats[f'excluded:{reason}'] += 1
                continue
            slot, meaning, keys = slot_of(path, noise)
            if slot is None:
                stats['excluded:no-neutral-slot'] += 1
                continue
            if meaning < PASS_SCORE:
                stats['excluded:meaning-weak'] += 1
                continue
            staged.append({'repo': name, 'path': path, 'slot': slot,
                           'keywords': keys, 'meaning': meaning})
        if not staged:
            continue
        clone = Path(index_root) / 'clones' / name
        folders = set()
        for c in staged:
            parts = PurePosixPath(c['path']).parts[:-1]
            folders.update('/'.join(parts[:i])
                           for i in range(len(parts) + 1))
        hint_paths = [r['path'] for r in records
                      if HINT_NAME.search(r['path'])
                      and parent_of(r['path']) in folders
                      and r['kind'] in ('data', 'other')]
        texts = {p: b.decode('utf-8', 'replace') for p, b in fetch_blobs(
            clone, header['commit'], hint_paths).items()}
        hints = file_hints([c['path'] for c in staged], texts)
        for c in staged:
            hint, source = hints.get(c['path'], (None, None))
            right, reason, cls = right_score(rclass, rnc, hint, rassets)
            if reason:
                stats[f'excluded:{reason}'] += 1
                continue
            if right < PASS_SCORE:
                stats['excluded:licence-weak'] += 1
                continue
            c.update({'right': right, 'licence': hint or rclass,
                      'licence_class': cls,
                      'licence_source': source or 'repository',
                      'share_alike': cls in SHARE_ALIKE,
                      'revision': header['commit'],
                      'url': header['repo']})
            candidates.append(c)
        log(f'{name}: audio={len(audio)} staged={len(staged)} '
            f'licence={rclass}{" NC/ND" if rnc else ""} '
            f'hints={len(hints)}')

    # Fetch the candidates, one batch per clone, into the cache.
    by_repo = defaultdict(list)
    for c in candidates:
        by_repo[c['repo']].append(c)

    def fetch_repo(name):
        blobs = fetch_blobs(Path(index_root) / 'clones' / name,
                            repos[name]['commit'],
                            [c['path'] for c in by_repo[name]])
        for c in by_repo[name]:
            data = blobs[c['path']]
            dest = cache_path(cache_root, name, c['path'])
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists() or dest.stat().st_size != len(data):
                dest.write_bytes(data)
            c['sha1'] = hashlib.sha1(data).hexdigest()
            c['bytes'] = len(data)
            c['cache'] = str(dest)
        return name, len(blobs)

    with ThreadPoolExecutor(max_workers=jobs) as ex:
        for name, count in ex.map(fetch_repo, sorted(by_repo)):
            log(f'fetched {count} from {name}')
    stats['fetched'] = len(candidates)

    # Identical bytes under two paths are one sound, and one name in
    # two encodings (door.ogg, door.mp3) is one sound too: the first by
    # extension order stays.
    seen, stems, unique = set(), set(), []
    order = {'.wav': 0, '.flac': 1, '.ogg': 2, '.opus': 3, '.mp3': 4}

    def by_stem(c):
        path = PurePosixPath(c['path'])
        return (c['repo'], str(path.with_suffix('')),
                order.get(path.suffix.lower(), 9))

    for c in sorted(candidates, key=by_stem):
        stem = by_stem(c)[:2]
        if c['sha1'] in seen:
            stats['excluded:duplicate-content'] += 1
            continue
        if stem in stems:
            stats['excluded:duplicate-encoding'] += 1
            continue
        seen.add(c['sha1'])
        stems.add(stem)
        unique.append(c)

    def measure_one(c):
        key = c['sha1']
        if key not in mcache:
            try:
                data, sr = decode(c['cache'])
                mcache[key] = measure(data, sr)
            except (ValueError, subprocess.SubprocessError, OSError) as exc:
                mcache[key] = {'error': str(exc)[:200]}
        return c

    with ThreadPoolExecutor(max_workers=jobs) as ex:
        list(ex.map(measure_one, unique))
    measure_cache_file.write_text(json.dumps(mcache), 'utf-8')

    pool = []
    for c in unique:
        prof = mcache[c['sha1']]
        if 'error' in prof:
            stats['excluded:decode-error'] += 1
            continue
        score, reason = acoustic_score(prof)
        if reason:
            stats[f'excluded:acoustic-{reason}'] += 1
            continue
        if score < PASS_SCORE:
            stats['excluded:acoustic-weak'] += 1
            continue
        c['profile'] = prof
        c['scores'] = {'right': c['right'], 'meaning': c['meaning'],
                       'acoustics': score}
        pool.append(c)
    stats['pool'] = len(pool)
    return {'stats': stats, 'repos': repos, 'candidates': candidates,
            'unique': unique, 'pool': pool}


# Eye check of the contact sheets (every chosen sound, drawn with
# --full-sheets into the cache): sounds whose spectrogram is plainly not
# what the slot says.  Each drop names its reason; the next in rank
# takes the place, so the selection stays deterministic.
_ALARM = 'an alarm tone (steady harmonic stack), not a motor or hull'
_CHIME = 'a tonal UI chime (decaying harmonic stack), not a switch'
_RING = ('rings with a few inharmonic partials and a long tail: the ear '
         'hears a small bell (no bell from raw material, TABOO 0.4 p. 4)')
_UNIT = 'part of a wesnoth unit attack set (attack, hit, die)'
_TC = 'drwhut__tabletop-club'
EYE_CHECK_DROPS = {
    (_SS14, 'Resources/Audio/Machines/warning_buzzer.ogg'): _ALARM,
    (_SS14, 'Resources/Audio/Machines/alarm.ogg'): _ALARM,
    (_SS14, 'Resources/Audio/Effects/Cargo/buzz_two.ogg'): _ALARM,
    (_SS14, 'Resources/Audio/Machines/airlock_emergencyon.ogg'): _ALARM,
    (_SS14, 'Resources/Audio/Machines/airlock_emergencyoff.ogg'): _ALARM,
    (_SS14, 'Resources/Audio/Effects/Cargo/ping.ogg'): _RING,
    (_SS14, 'Resources/Audio/Animals/nymph_chirp.ogg'):
        'one synthetic tone line of a game creature, not a bird',
    (_SS14, 'Resources/Audio/Effects/PowerSink/charge_fire.ogg'):
        'rising electric chirps, not fire',
    (_SS14, 'Resources/Audio/Misc/zip.ogg'):
        'the same sound as Items/zip.ogg (same spectrogram)',
    ('magefree__mage', 'Mage.Client/sounds/OnSkipButton.wav'): _CHIME,
    ('magefree__mage', 'Mage.Client/sounds/OnSkipButtonCancel.wav'):
        _CHIME,
    ('magefree__mage', 'Mage.Client/sounds/OnButtonCancel.wav'): _CHIME,
    ('Card-Forge__forge', 'forge-gui/res/sound/equip.mp3'):
        'a tonal card-game cue, not cloth',
    ('wesnoth__wesnoth', 'data/core/sounds/axe.ogg'): _UNIT,
    ('wesnoth__wesnoth', 'data/core/sounds/fire.wav'): _UNIT,
    ('wesnoth__wesnoth', 'data/core/sounds/wolf-growl-1.ogg'): _UNIT,
    ('wesnoth__wesnoth', 'data/core/sounds/wolf-growl-2.ogg'): _UNIT,
    ('wesnoth__wesnoth', 'data/core/sounds/wolf-growl-3.ogg'): _UNIT,
    ('wesnoth__wesnoth', 'data/core/sounds/wolf-growl-4.ogg'): _UNIT,
    (_SS14, 'Resources/Audio/Effects/Footsteps/bounce.ogg'):
        'a rubber bounce with tone lines, not a step',
    (_SS14, 'Resources/Audio/Machines/genetics.ogg'):
        'a tonal beep sequence, not a motor',
    ('widelands__widelands', 'data/sound/farm/scythe_00.ogg'):
        'a scythe mowing in the farm folder, not an animal',
}
EYE_CHECK_DROPS.update({
    (_TC, f'game/Sounds/{folder}/impactMetal_{weight}_{n:03d}.ogg'): _RING
    for folder, weight in (('MetalLight', 'light'), ('Metal', 'medium'),
                           ('MetalHeavy', 'heavy'))
    for n in range(5)})


# --- Contact sheet -----------------------------------------------------

_CMAP = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110],
                  [159, 42, 99], [212, 72, 66], [245, 125, 21],
                  [250, 193, 39], [252, 255, 164]], dtype=np.float64)


def colormap(v):
    """An inferno-like ramp for values in 0..1 (numpy, no matplotlib)."""
    v = np.clip(v, 0, 1) * (len(_CMAP) - 1)
    lo = np.floor(v).astype(int)
    hi = np.minimum(lo + 1, len(_CMAP) - 1)
    f = (v - lo)[..., None]
    return (_CMAP[lo] * (1 - f) + _CMAP[hi] * f).astype(np.uint8)


def spectrogram_tile(path, width=240, height=112):
    """Log-frequency spectrogram (60 Hz..16 kHz, 80 dB range) as RGB."""
    data, sr = decode(path)
    mono = data.mean(axis=1) if data.ndim > 1 else data
    power, freqs, _ = stft_power(mono.astype(np.float64), sr)
    db = 10 * np.log10(power + 1e-20)
    db = (db - db.max() + 80) / 80
    edges = np.geomspace(60, min(16000, sr / 2), height + 1)
    rows = []
    for i in range(height):
        sel = (freqs >= edges[i]) & (freqs < edges[i + 1])
        if sel.any():
            rows.append(db[:, sel].max(axis=1))
        else:
            j = int(np.argmin(np.abs(freqs - edges[i])))
            rows.append(db[:, j])
    img = np.array(rows[::-1])
    cols = np.linspace(0, img.shape[1] - 1, width).round().astype(int)
    return colormap(img[:, cols])


def contact_sheet(items, out, per_row=6):
    """Draw the spectrograms of items with a label each into out."""
    from PIL import Image, ImageDraw, ImageFont
    tw, th, lab = 240, 112, 30
    rows = math.ceil(len(items) / per_row)
    sheet = Image.new('RGB', (per_row * (tw + 8) + 8,
                              rows * (th + lab + 8) + 40), (18, 16, 14))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 11)
        big = ImageFont.truetype(
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
    except OSError:
        font = big = ImageFont.load_default()
    draw.text((8, 10), f'{PASS_ID}: spectral references only (TABOO 0.35 '
              'rule 8); 60 Hz-16 kHz log, 80 dB', fill=(230, 220, 200),
              font=big)
    for i, c in enumerate(items):
        x = 8 + (i % per_row) * (tw + 8)
        y = 40 + (i // per_row) * (th + lab + 8)
        try:
            tile = Image.fromarray(spectrogram_tile(c['cache'], tw, th))
            sheet.paste(tile, (x, y))
        except (ValueError, subprocess.SubprocessError, OSError):
            draw.rectangle((x, y, x + tw, y + th), outline=(200, 0, 0))
        label = PurePosixPath(c['path']).name
        draw.text((x, y + th + 2), f'{c.get("n", i + 1)} {c["slot"]}',
                  fill=(250, 193, 39), font=font)
        draw.text((x, y + th + 15), f'{c["repo"].split("__")[-1][:14]}: '
                  f'{label[:26]}', fill=(220, 210, 190), font=font)
    out.parent.mkdir(parents=True, exist_ok=True)
    # 48 colours read the same to the eye as 128 and weigh 28 % less
    # (517 -> 372 KB on the first sheet; TABOO 0.011: growth is measured).
    sheet = sheet.convert('P', palette=Image.ADAPTIVE, colors=48)
    sheet.save(out, optimize=True)


# --- Writers -----------------------------------------------------------

def _rows_json(rows):
    """One compact JSON object per line: small, and diffs stay readable."""
    return '[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False,
                                         separators=(',', ':'))
                              for r in rows) + '\n]\n'


def reference_row(c):
    return {'n': c['n'], 'slot': c['slot'], 'repo': c['url'],
            'revision': c['revision'], 'path': c['path'],
            'licence': c['licence'], 'licence_class': c['licence_class'],
            'licence_source': c['licence_source'],
            'share_alike': c['share_alike'], 'tier': c['tier'],
            'scores': c['scores'],
            'sha1': c['sha1'], 'bytes': c['bytes'],
            'profile': dict(c['profile'],
                            impulsive=is_impulsive(c['profile']))}


def props_row(c):
    """Props register row of TABOO 0.012 (schema shared with the image
    props register: do not add fields here)."""
    return {'repo': c['url'], 'revision': c['revision'], 'path': c['path'],
            'licence': c['licence'], 'kind': 'audio',
            'deficit_id': DEFICIT_ID, 'keywords': c['keywords'],
            'pass_id': PASS_ID, 'sha1': c['sha1'], 'bytes': c['bytes']}


def slot_profiles(chosen):
    """Median reference values per slot, the first thing a synth reads."""
    out = {}
    for slot, spec in SLOTS.items():
        rows = [c['profile'] for c in chosen if c['slot'] == slot]
        # Only blows that die away give a T60 of the thing itself.
        t60 = [p['t60_s'] for p in rows if p['t60_s'] is not None
               and p['t60_method'] in ('T20', 'T30') and is_impulsive(p)]
        out[slot] = {
            'place': spec['place'], 'use': spec['use'], 'n': len(rows),
            't60_median_s': round(float(np.median(t60)), 3) if t60
            else None,
            't60_n': len(t60),
            'centroid_median_hz': round(float(np.median(
                [p['centroid_hz'] for p in rows])), 1) if rows else None,
            'attack_median_ms': round(float(np.median(
                [p['attack_ms'] for p in rows])), 1) if rows else None,
        }
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', default='/home/user/raw-repos')
    parser.add_argument('--cache', default='/home/user/raw-audio')
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--write', action='store_true',
                        help='write the repository outputs')
    parser.add_argument('--full-sheets', action='store_true',
                        help='draw every chosen sound into the cache')
    args = parser.parse_args()

    result = run_pass(args.index, args.cache, args.jobs)
    stats, pool = result['stats'], result['pool']
    pool = [c for c in pool
            if (c['repo'], c['path']) not in EYE_CHECK_DROPS]
    stats['excluded:eye-check'] = len(result['pool']) - len(pool)
    tier1, _ = select(pool, tiers=((FOLDER_CAP, REPO_CAP),))
    stats['chosen-tier1-only'] = len(tier1)
    ceiling, _ = select(pool, k=len(pool), tiers=((10 ** 6, 10 ** 6),))
    stats['ceiling-two-states-per-thing'] = len(ceiling)
    chosen, cut = select(pool)
    for i, c in enumerate(chosen, 1):
        c['n'] = i
    stats['chosen'] = len(chosen)
    stats['chosen-tier2'] = sum(c['tier'] == 2 for c in chosen)
    stats['cut-by-diversity-caps'] = cut
    for key in sorted(stats):
        print(f'{key}: {stats[key]}')
    print('by slot:', dict(Counter(c['slot'] for c in chosen)))
    print('by repo:', dict(Counter(c['repo'] for c in chosen)))

    if args.full_sheets:
        for i in range(0, len(chosen), SHEET_SAMPLE):
            out = Path(args.cache) / '_sheets' / \
                f'sheet-{i // SHEET_SAMPLE + 1:02d}.png'
            contact_sheet(chosen[i:i + SHEET_SAMPLE], out)
            print('sheet', out)
    if not args.write:
        return
    write_outputs(result, chosen, stats, args.cache)


def cache_mb(cache_root):
    total = sum(f.stat().st_size for f in Path(cache_root).rglob('*')
                if f.is_file())
    return round(total / 1e6, 1)


def prune_cache(cache_root, candidates):
    """Remove audio files of earlier, looser runs from the cache, so
    the store holds exactly the props rows of this pass (TABOO 0.012).
    Only files under the cache root are touched, never the repo."""
    cache_path(cache_root, 'x', 'y')  # raises if the root is in ROOT
    keep = {Path(c['cache']).resolve() for c in candidates}
    removed = 0
    for f in Path(cache_root).resolve().rglob('*'):
        if f.is_file() and f.suffix.lower() in DECODABLE \
                and f not in keep:
            f.unlink()
            removed += 1
    return removed


def write_outputs(result, chosen, stats, cache_root):
    """Write the table, references, props, notices, sheet and journal."""
    stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    refs = {
        'pass_id': PASS_ID, 'deficit_id': DEFICIT_ID, 'generated': stamp,
        'rule': 'CLAUDE.md TABOO 0.35 rule 8: audio from the 99 repos is '
                'a spectral reference only (envelope, T60, IR) and never '
                'a sample in the game. No audio file ships.',
        'units': {'t60_s': 'Schroeder backward integration, fit -5..-25 '
                  'dB (T20) or -5..-35 dB (T30); T10 is partial',
                  'edc_db': '12 points of the energy decay curve from the '
                  'peak to where the decay meets the noise floor',
                  'envelope_db': '16 max-pooled points over the duration, '
                  'dB relative to the peak (2 ms blocks)',
                  'bands_db': 'octave-band energy relative to the total',
                  'band_t60_s': 'Schroeder T60 per octave band (STFT)'},
        'slot_profiles': slot_profiles(chosen),
    }
    text = json.dumps(refs, ensure_ascii=False, indent=1)
    text = text[:-2] + ',\n "references": ' + \
        _rows_json([reference_row(c) for c in chosen]).rstrip('\n') + '\n}\n'
    OUT_REFS.write_text(text, 'utf-8')
    props = [props_row(c) for c in sorted(
        result['candidates'], key=lambda c: (c['repo'], c['path']))]
    OUT_PROPS.write_text(_rows_json(props), 'utf-8')
    sample = sheet_sample(chosen)
    contact_sheet(sample, OUT_SHEET)
    write_notices(chosen, result['repos'])
    write_table(chosen, stats, result, sample)
    growth = {p.name: p.stat().st_size for p in (OUT_REFS, OUT_PROPS,
                                                 OUT_SHEET, OUT_TABLE)}
    pruned = prune_cache(cache_root, result['candidates'])
    taken_mb = round(sum(c['bytes'] for c in result['candidates']) / 1e6,
                     1)
    entry = {
        'time': stamp, 'type': 'audio-pass', 'pass_id': PASS_ID,
        'deficits': [{'id': DEFICIT_ID, 'taken': len(chosen)}],
        'accepted_objects': 0, 'code_candidates': 0,
        'counts': {k: v for k, v in sorted(stats.items())},
        'props_taken': {'audio': len(result['candidates'])},
        'by_slot': dict(Counter(c['slot'] for c in chosen)),
        'by_repo': dict(Counter(c['repo'] for c in chosen)),
        'cache_mb': cache_mb(cache_root),
        'taken_mb': taken_mb,
        'cache_pruned_files': pruned,
        'written_bytes': growth,
        'note': 'Spectral references only (TABOO 0.35 rule 8): no audio '
                'file in the repository, godot/ or public/. Props rows '
                'in docs/RAW_AUDIO_PROPS.json (TABOO 0.012).',
    }
    cursor = json.loads(CURSOR.read_text('utf-8'))
    cursor['log'].append(entry)
    CURSOR.write_text(json.dumps(cursor, ensure_ascii=False, indent=1),
                      'utf-8')
    print('written', growth, 'cache MB', entry['cache_mb'],
          'taken MB', taken_mb, 'pruned', pruned)


def write_notices(chosen, repos):
    """Append one section naming the repositories used as references."""
    head = f'## Spectral references of the audio pass {PASS_ID}'
    existing = NOTICES.read_text('utf-8')
    if head in existing:
        return
    per = defaultdict(list)
    for c in chosen:
        per[c['repo']].append(c)
    lines = ['', head, '',
             'Measured profiles only (envelope, T60, spectral centroid, '
             'decay), CLAUDE.md', 'TABOO 0.35 rule 8: no sound from these '
             'repositories is shipped or', 'sampled. Per-file licences '
             'and paths: docs/RAW_AUDIO_REFERENCES.json.', '',
             '| Repository | Commit | Licences of the used files | '
             'Files | Share-alike |', '|---|---|---|---|---|']
    for name in sorted(per):
        rows = per[name]
        lic = ', '.join(sorted({c['licence_class'] for c in rows}))
        sa = sum(c['share_alike'] for c in rows)
        lines.append(f'| {repos[name]["url"]} | '
                     f'{repos[name]["commit"][:10]} | {lic} | {len(rows)} '
                     f'| {sa} |')
    NOTICES.write_text(existing.rstrip('\n') + '\n' + '\n'.join(lines)
                       + '\n', 'utf-8')


def write_table(chosen, stats, result, sample):
    """The document for the operator, the sound designer and the lawyer."""
    ex = {k.split(':', 1)[1]: v for k, v in stats.items()
          if k.startswith('excluded:') and v}
    lines = [
        '# RAW_AUDIO_299 — звуки из 99 репо как спектральные эталоны '
        '(2026-09-30)', '',
        f'Проход `{PASS_ID}`, дефицит {DEFICIT_ID}. Скрипт: '
        '`scripts/raw_assets/audio_pass.py`; HLD: '
        '`docs/HLD_AUDIO_299_2026-09-30.md`.', '',
        '**Главное.** ТАБУ №0.35 п. 8: звук из 99 репо — только '
        'спектральный эталон (огибающая, T60, IR), никогда не сэмпл. '
        'Поэтому «добавить 299 звуков» значит: отобрать, замерить и '
        'записать профили в `docs/RAW_AUDIO_REFERENCES.json`. '
        'Проход не кладёт ни одного аудиофайла в репо, `godot/` и '
        '`public/`; сами файлы лежат в кэше вне репо '
        '(`/home/user/raw-audio`).', '',
        '## Честный счёт', '',
        f'- аудиофайлов в индексе: **{stats["index-audio"]}**;',
        f'- взято в кэш (прошли путь и лицензию): **{stats["fetched"]}** '
        '— это реквизит (ТАБУ №0.012), строки в '
        '`docs/RAW_AUDIO_PROPS.json`;',
        f'- честный пул N (все три параметра ≥ {PASS_SCORE}): '
        f'**{stats["pool"]}**;',
        f'- отобрано K: **{stats["chosen"]}** из просимых {K};',
        f'  - ярус 1 — ограничения задачи (≤ {FOLDER_CAP} на папку, '
        f'≤ {REPO_CAP} на репо, минимум {SLOT_MIN} на слот, ≤ '
        f'{THING_CAP} состояния одной вещи): '
        f'**{stats["chosen"] - stats["chosen-tier2"]}**;',
        f'  - ярус 2 — только правило ТАБУ №0.07 п. 4 (≤ {THING_CAP} '
        'состояния одной вещи), без потолков папки и репо: '
        f'**{stats["chosen-tier2"]}**;',
        f'- честный потолок при ≤ {THING_CAP} состояниях на вещь: '
        f'**{stats["ceiling-two-states-per-thing"]}**; один ярус 1 '
        f'дал бы {stats["chosen-tier1-only"]}.', '',
        'Почему два яруса: оператор просил 299, честный пул больше, а '
        'потолки задачи (3 на папку, 40 на репо) дают меньше. Ярус 1 '
        'сохраняет их разнообразие; ярус 2 добирает до 299 без повторов '
        'одной вещи. У каждой строки в `docs/RAW_AUDIO_REFERENCES.json` '
        'есть поле `tier`: кому нужен строгий набор — берёт ярус 1.', '',
    ]
    if stats['chosen'] < K:
        lines += [
            f'**{K} честно не набирается.** Добивать выдумкой запрещено '
            '(ТАБУ №0.07): пишется реальное число и причина — ниже '
            'таблица исключений.', '']
    lines += ['## Исключено, по причинам', '',
              '| Причина | Файлов |', '|---|---|']
    for k in sorted(ex, key=lambda k: -ex[k]):
        lines.append(f'| {k} | {ex[k]} |')
    lines += ['', '## Три параметра (0–10, в коде, детерминированно)', '',
              '- **ПРАВО** — лицензия: по файлу (attributions.yml, '
              'copyrights.csv, Debian copyright, таблицы CREDITS) +1, '
              'иначе по репо; кодовая лицензия без слова об ассетах −2; '
              'NC/ND и репо без лицензии — исключены.',
              '- **СМЫСЛ** — нейтральный слот по словам пути; сильное '
              'слово в имени файла 8, в папке 5; святое, стоп-лист, '
              'музыка, «награды», голоса, бой, враги — исключены до '
              'подсчёта.',
              '- **АКУСТИКА** — из декодированного файла: частота ≥ 22,05 '
              'кГц, длина 0,05–30 с, без клиппинга, шумовой пол, '
              'огибающая, T60 по Шрёдеру, центроид, спад по полосам.', '',
              '## Слоты', '',
              'T60 медиана — только по одиночным ударам (не больше '
              'четверти огибающей в пределах 10 дБ от пика, после пика '
              'спад ниже −20 дБ; поле `impulsive`): у ветра, дождя, гула '
              'и серии ударов подогнанный «T60» — это затухание файла, а '
              'не вещи и не помещения. «—» — в слоте нет одиночных '
              'ударов.', '',
              '| Слот | Где | Для чего в игре | K | T60 медиана (удары), '
              'с | Центроид медиана, Гц |', '|---|---|---|---|---|---|']
    prof = slot_profiles(chosen)
    for slot, spec in SLOTS.items():
        p = prof[slot]
        t60 = '—' if p['t60_median_s'] is None else p['t60_median_s']
        lines.append(f'| {slot} | {spec["place"]} | {spec["use"]} | '
                     f'{p["n"]} | {t60} | {p["centroid_median_hz"]} |')
    empty = [s for s in SLOTS if prof[s]['n'] == 0]
    if empty:
        lines += ['', 'Слоты без единого звука: ' + ', '.join(empty)
                  + ' — в 99 репо нет честного материала под них.']
    lines += ['', '## Таблица K', '',
              'П — право, С — смысл, А — акустика; T60 — метод T20/T30 '
              '(T10 — частичный), «—» — нет хвоста спада, «ф» — спад '
              'файла у сплошного звука, не помещения; Я — ярус.', '',
              '| # | Слот | Репо | Путь | Лицензия | П | С | А | Я | '
              'T60, с | Центроид, Гц |',
              '|---|---|---|---|---|---|---|---|---|---|---|']
    for c in chosen:
        p = c['profile']
        t60 = f'{p["t60_s"]} {p["t60_method"]}' if p['t60_s'] else '—'
        if p['t60_s'] and not is_impulsive(p):
            t60 += ' ф'
        s = c['scores']
        lines.append(
            f'| {c["n"]} | {c["slot"]} | {c["repo"].replace("__", "/")} | '
            f'`{c["path"]}` | {c["licence"]} | {s["right"]} | '
            f'{s["meaning"]} | {s["acoustics"]} | {c["tier"]} | {t60} | '
            f'{p["centroid_hz"]} |')
    lines += [
        '', '## Контактный лист', '',
        f'`docs/audit/2026-09-30/raw-audio-299-spectra.png` — '
        f'{len(sample)} спектрограмм (по кругу слотов, в порядке ранга). '
        'Глазами просмотрены спектрограммы всех выбранных звуков '
        '(полные листы — в кэше, `/home/user/raw-audio/_sheets/`); '
        'снятое ниже, следующий по рангу занял место.', '',
        '## Снято ревью и глазами', '',
        '| Репо | Путь | Почему |', '|---|---|---|']
    for (repo, path), why in sorted({**REVIEW_DROPS,
                                     **EYE_CHECK_DROPS}.items()):
        lines.append(f'| {repo.replace("__", "/")} | `{path}` | {why} |')
    share = sum(c['share_alike'] for c in chosen)
    by_repo_only = sum(c['licence_source'] == 'repository' for c in chosen)
    lines += [
        '', '## Что проверить до релиза', '',
        '**Звукорежиссёр:** прослушать хотя бы лист из 48; проверить, что '
        'T60 одиночных ударов (`impulsive: true`) в слотах rov.hull, '
        'workshop.stone и workshop.wood правдоподобны для синтеза (у '
        'игровых эффектов хвост часто обрезан редактором); решить, какие '
        'профили берёт `dive_synth.gd` (гул, пинг, пузыри) — это шаг '
        'в APK, он в HLD.', '',
        '**Юрист:** (1) замер эталона не распространяет звук, но реестр '
        'ведётся как для сырья; (2) share-alike (GPL, CC-BY-SA, MPL) — '
        f'{share} из {len(chosen)} строк, отмечен в каждой: если звук '
        'когда-нибудь станет сэмплом, обязанности share-alike вернутся; '
        '(3) строки с `licence_source: repository` '
        f'({by_repo_only} из {len(chosen)}) — лицензия ассета не '
        'подтверждена отдельным файлом (для MIT-репо '
        'это лицензия кода, ПРАВО снижено на 2); (4) репо без лицензии '
        'в корне (freeorion, micropolis, unknown-horizons, angband, '
        'cocos2d-x, urho3d, ja2-stracciatella) исключены целиком, хотя '
        'у некоторых есть лицензия в подпапке — решение за юристом; '
        '(5) Custom — лицензия Defold (Apache-подобная с оговорками), '
        'проверить.', '',
    ]
    OUT_TABLE.write_text('\n'.join(lines), 'utf-8')


if __name__ == '__main__':
    main()
