"""The church-word stop-list, read from its one file.

No church word labels a place, a thing, a button or a narrator's line
(CLAUDE.md TABOO 0.39 item 3, 0.4 item 7).  The words live once, in
godot/data/church-words.json; the headset (LocationsCore), the web
tests and this generator read that file and match it the same way, so
the lists cannot drift (docs/decisions/STOPLIST_SINGLE_SOURCE_*.md).

A word is a run of the letters a-z and а-я after lower case, with ё
read as е.  A word is a church word when it does not begin with an
allowed twin and either equals a listed form or begins with a stem.
Matching from the start of a word keeps «помощи» clear of «мощи»; the
twins keep «крестьянин» clear of «крест».
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'godot' / 'data' / 'church-words.json'

# The same letters the GDScript and JS matchers treat as a word.
WORD = re.compile('[a-zа-я]+')


def load(path=DATA):
    """Return the stop-list as a dict of stems, forms and twins."""
    with open(path, encoding='utf-8') as f:
        return json.load(f)


LIST = load()


def words(text):
    """Split a text into its lower-case words, ё read as е."""
    return WORD.findall(text.lower().replace('ё', 'е'))


def church_word(text, data=None):
    """Return the first church word of a text, or '' when it is plain."""
    data = data or LIST
    for w in words(text):
        if any(w.startswith(t) for t in data['twins']):
            continue
        if w in data['forms']:
            return w
        if any(w.startswith(s) for s in data['stems']):
            return w
    return ''


def has_church_word(text, data=None):
    """Tell whether a text holds a church word."""
    return church_word(text, data) != ''
