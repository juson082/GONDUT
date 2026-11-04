// Verify translated UI characters against the bundled font's Unicode cmap.
const fs = require('node:fs');
const font = fs.readFileSync(process.argv[2] ?? 'assets/Xiaolai-Regular.ttf');
const u16 = offset => font.readUInt16BE(offset);
const u32 = offset => font.readUInt32BE(offset);
let cmap = 0;
for (let i = 0; i < u16(4); i++) {
  const table = 12 + i * 16;
  if (font.toString('ascii', table, table + 4) === 'cmap') cmap = u32(table + 8);
}
if (!cmap) throw new Error('Missing cmap table');
const subtables = [];
for (let i = 0; i < u16(cmap + 2); i++) {
  const offset = cmap + u32(cmap + 8 + i * 8);
  if ([4, 12].includes(u16(offset))) subtables.push(offset);
}
function contains(code) {
  return subtables.some(offset => {
    if (u16(offset) === 12) {
      for (let i = 0; i < u32(offset + 12); i++) {
        const p = offset + 16 + 12 * i, start = u32(p), end = u32(p + 4);
        if (code >= start && code <= end) return u32(p + 8) + code - start !== 0;
      }
      return false;
    }
    if (code > 0xffff) return false;
    const n = u16(offset + 6) / 2, ends = offset + 14;
    const starts = ends + 2 * n + 2, deltas = starts + 2 * n, ranges = deltas + 2 * n;
    for (let i = 0; i < n; i++) {
      if (code < u16(starts + 2 * i) || code > u16(ends + 2 * i)) continue;
      const delta = u16(deltas + 2 * i), range = u16(ranges + 2 * i);
      if (!range) return ((code + delta) & 0xffff) !== 0;
      const glyph = u16(ranges + 2 * i + range + 2 * (code - u16(starts + 2 * i)));
      return glyph !== 0 && ((glyph + delta) & 0xffff) !== 0;
    }
    return false;
  });
}
const sources = ['lib/app_strings.dart', 'lib/extra_translations.dart'].map(file => fs.readFileSync(file, 'utf8')).join('\n');
// Include all Unicode letters, combining marks and numbers, so newly added
// languages are checked too rather than silently skipped by a CJK-only list.
const letters = [...new Set([...sources].filter(char => /[\p{L}\p{M}\p{N}]/u.test(char)))];
const missing = letters.filter(char => !contains(char.codePointAt(0)));
if (missing.length) throw new Error(`Missing translated UI characters: ${missing.join('')}`);
console.log(`Font covers ${letters.length} unique translated UI characters.`);
