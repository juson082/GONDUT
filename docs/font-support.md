# Notebook font and future languages

The app uses Xiaolai as `GondutHand` for the interface and the
default note style in every locale. The font and its SIL Open Font License
are bundled locally; no font download is needed by app users. Its source is
https://github.com/lxgw/kose-font.

The unmodified regular font is from upstream release `v3.126`; its SHA-256 is
`e2f68daf0e72777a8cf58bc83de1b98634b251e537ddbfca24b0ae50d1802da2`.
The bundled `licenses/Xiaolai-OFL.txt` (including its copyright notice)
came from upstream commit `5359953d118976c7797ad3257d7cf4036ad09f3c`;
its SHA-256 is `0df7e09be4c2c850a48bd8beb9cd64b343aad49cd5d3f6cfb2ad2e3d28a56ca4`.
The app registers this notice on Flutter's open-source licenses page.

When adding a language, add its translations and run
`node tool/check_font_coverage.cjs` from the project root. This checks letters,
combining marks and numbers in the current translation catalogs. Expand the
catalog paths in the script if translations move to another format or file.
Also review punctuation and representative user-entered text in the new
language on a device; the catalog check does not cover arbitrary user input.

The font does not cover every script or rare character. Flutter can fall back
to the device font for a missing glyph, so unsupported text remains readable,
but that glyph will not necessarily match the handwriting style. A new script
with missing glyphs needs a compatible handwriting font or a licensed font
extension, followed by another coverage and visual review.
