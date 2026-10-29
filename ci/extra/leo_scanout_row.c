/*
 * leo_scanout_row.c - the row converter the published HD2 tree refers to but
 * does not carry (the source audit lists leo_scanout_row.c as present in the
 * 036 snapshot and absent from the public tree, and pexpert/arm/
 * pe_qsd8250_leo.c calls it once per line).
 *
 * Contract, taken from the caller and from IOS7LeoScanoutRow.h:
 *
 *     void leo_scanout_copy_row(volatile uint16_t *out,
 *                               const uint8_t *pixels, uint32_t format);
 *
 * The caller hands one line at a time, `pixels + y * row`, and writes into
 * `leo_pixels + y * 480`, so exactly 480 destination pixels per call.  The
 * panel is RGB565 (leo_handoff.h defines IOS7LAB_LEO_RGB565 as 'R565' and the
 * handoff check refuses any other pixel_format), so the destination is 16 bits
 * per pixel and 960 bytes per row.
 *
 * Interrupts are off around this call and it runs once per line per frame, so
 * it stays arithmetic only: no library calls, no divisions, no I/O.
 */

#include <stdint.h>

#define LEO_RGB565	0x35363552U	/* IOS7LAB_LEO_RGB565, leo_handoff.h */
#define LEO_ROW_PIXELS	480

/* 8888 source assumed for any other format value: the handoff validator in
 * pe_qsd8250_leo.c rejects everything except RGB565, so this branch only
 * exists so a wrong stride cannot silently paint garbage. */
void
leo_scanout_copy_row(volatile uint16_t *out, const uint8_t *pixels,
    uint32_t format)
{
	for (unsigned int x = 0; x < LEO_ROW_PIXELS; x++) {
		uint16_t v;

		if (format == LEO_RGB565) {
			v = (uint16_t)((uint16_t)pixels[x * 2] |
			    ((uint16_t)pixels[x * 2 + 1] << 8));
		} else {
			uint8_t r = pixels[x * 4 + 1];
			uint8_t g = pixels[x * 4 + 2];
			uint8_t b = pixels[x * 4 + 3];

			v = (uint16_t)(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3));
		}
		out[x] = v;
	}
}
