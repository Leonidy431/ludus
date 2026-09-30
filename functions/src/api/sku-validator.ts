/**
 * SKU validator against simony (HLD F5, DEF-021; CLAUDE.md TABOO 0.35
 * rules 15-16, TABOO 0.39 item 3).
 *
 * "Thy money perish with thee, because thou hast thought that the gift
 * of God may be purchased with money" (Acts 8:20; Apostolic Canon 29).
 * So nothing sold in Ludus may:
 *   - name a holy thing, rank or state in its title, description or
 *     bonus (grace, prayer, sacrament, relic, icon, blessing, orders,
 *     salvation ... in English and Russian);
 *   - change FORM (the seven attributes), open a gate, add XP or a
 *     multiplier: monetisation is cosmetic only;
 *   - be priced in an attribute (faith, wisdom ...) or in "knowledge":
 *     an attribute is a state of the soul, not a currency;
 *   - give a random reward (loot box, chance, gacha, mystery box);
 *   - be a cryptocurrency, NFT or blockchain certificate.
 * The validator is pure, so it runs in tests and in any endpoint that
 * lists or sells an item.  It returns every problem, not the first.
 */

export interface Sku {
  id: string;
  title: string;
  title_ru?: string;
  description?: string;
  description_ru?: string;
  cosmetic: boolean;
  price: Record<string, number>;
  bonuses?: Record<string, number>;
  opensGate?: string | null;
  randomReward?: boolean;
}

export const ATTRIBUTES = ['wisdom', 'faith', 'dexterity', 'constitution',
  'charisma', 'cunning', 'erudition'];

// Only money may be a price.  "gold" is the in-game coin of the text
// version; real-money prices are the store's, in minor units.
export const CURRENCIES = ['gold', 'usd_cents', 'eur_cents', 'rub_kopecks'];

// Holy things, ranks and states that are never a product (EN and RU
// stems).  Word stems are matched at word starts, so "iconic" is caught
// too: a skin called "Iconic halo" is exactly the problem.
const SACRED = [
  'grace', 'bless', 'prayer', 'pray', 'sacrament', 'eucharist',
  'communion', 'absolution', 'confession', 'baptism', 'chrism',
  'unction', 'relic', 'icon', 'holy', 'saint', 'martyr', 'salvation',
  'redemption', 'indulgence', 'halo', 'nimbus', 'ordination', 'priest',
  'deacon', 'bishop', 'monk', 'elder', 'schema', 'liturgy', 'gospel',
  'cross', 'crucifix', 'chalice', 'censer', 'bell', 'jesus', 'christ',
  'theotokos', 'god',
  'благодат', 'благослов', 'молитв', 'таинств', 'причаст', 'евхарист',
  'исповед', 'крещен', 'миропомаз', 'елеосвящ', 'мощи', 'икон', 'свят',
  'мученик', 'спасени', 'индульгенц', 'нимб', 'рукоположен', 'сан ',
  'священ', 'диакон', 'дьякон', 'епископ', 'монах', 'схим', 'старец',
  'литурги', 'евангел', 'крест', 'потир', 'кадил', 'колокол', 'иисус',
  'христ', 'богородиц', 'бог',
];

// Words that betray a random or speculative reward.
const RANDOM = ['loot', 'lootbox', 'gacha', 'mystery', 'random', 'chance',
  'lucky', 'crate', 'nft', 'crypto', 'token', 'blockchain',
  'лутбокс', 'сундук удачи', 'случайн', 'шанс', 'крипт', 'токен'];

function textOf(sku: Sku): string {
  return [sku.id, sku.title, sku.title_ru, sku.description,
    sku.description_ru].filter(Boolean).join(' ').toLowerCase();
}

function hits(text: string, stems: string[]): string[] {
  return stems.filter((stem) => {
    const s = stem.trim();
    // Cyrillic has no \b in JS regexes, so match a stem at the start of
    // the text or after a non-letter.
    const re = new RegExp(`(^|[^a-zа-яё])${s.replace(/[.*+?^${}()|[\]\\]/g,
      '\\$&')}`, 'iu');
    return re.test(text);
  });
}

/** Every reason the SKU may not be sold; empty when it may. */
export function validateSku(sku: Sku): string[] {
  const problems: string[] = [];
  const text = textOf(sku);
  hits(text, SACRED).forEach((w) =>
    problems.push(`names a holy thing or rank: "${w.trim()}"`));
  hits(text, RANDOM).forEach((w) =>
    problems.push(`random or speculative reward: "${w.trim()}"`));
  if (sku.cosmetic !== true) {
    problems.push('only cosmetic items may be sold');
  }
  Object.keys(sku.bonuses || {}).forEach((k) => {
    problems.push(ATTRIBUTES.includes(k.toLowerCase())
      ? `changes FORM (${k})` : `grants a bonus or multiplier (${k})`);
  });
  if (sku.opensGate) {
    problems.push(`opens a gate (${sku.opensGate})`);
  }
  if (sku.randomReward) {
    problems.push('random reward');
  }
  const priceKeys = Object.keys(sku.price || {});
  if (priceKeys.length === 0) {
    problems.push('no price');
  }
  priceKeys.forEach((k) => {
    if (ATTRIBUTES.includes(k.toLowerCase())) {
      problems.push(`priced in an attribute (${k})`);
    } else if (!CURRENCIES.includes(k)) {
      problems.push(`unknown currency (${k})`);
    } else if (!(Number.isInteger(sku.price[k]) && sku.price[k] > 0)) {
      problems.push(`price ${k} must be a positive whole number`);
    }
  });
  return problems;
}
