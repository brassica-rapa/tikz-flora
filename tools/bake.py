#!/usr/bin/env python3
"""
tools/bake.py: Bake procedural flora into lightweight transparent images.

Usage:
    python3 tools/bake.py [options]

Options:
    --layout LAYOUT    Layout to bake: left, right, title, surround, centered (default: all)
    --seed SEED        Document seed (default: 1)
    --page PAGE        Page number (default: 1)
    --palette PALETTE  Palette preset or ink name (optional)
    --dpi DPI          Resolution in DPI (default: 300)
    --outdir DIR       Output directory for images (default: tex/baked)
    --batch            Bake the standard set of layouts and seeds

When a TeX distribution (texlua & pdftocairo) is available, this tool renders
the exact procedural flora using tools/preview.lua and rasterizes it into 300 DPI
transparent PNGs in tex/baked/. These images are automatically loaded by
tikzflora.sty, eliminating vector calculation overhead during document compile.
"""

import argparse
import ctypes
import math
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUTDIR = os.path.join(ROOT, "tex", "baked")


def find_binary(name):
    """Find a binary in PATH or common TeX Live / TinyTeX locations."""
    found = shutil.which(name)
    if found:
        return found
    custom_dir = os.environ.get("FLORA_TEX_BIN")
    if custom_dir:
        cand = os.path.join(custom_dir, name)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    candidates = [
        os.path.expanduser("~/Library/TinyTeX/bin/universal-darwin"),
        os.path.expanduser("~/Library/TinyTeX/bin/x86_64-darwin"),
        os.path.expanduser("~/.TinyTeX/bin/x86_64-linux"),
        "/Library/TeX/texbin",
        "/usr/local/bin",
    ]
    for d in candidates:
        cand = os.path.join(d, name)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def get_cairo():
    """Attempt to load libcairo via ctypes with proper argtypes."""
    for libname in ["libcairo.so.2", "libcairo.2.dylib", "cairo"]:
        try:
            c = ctypes.CDLL(libname)
            c.cairo_image_surface_create.restype = ctypes.c_void_p
            c.cairo_create.restype = ctypes.c_void_p
            c.cairo_surface_write_to_png.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
            c.cairo_set_source_rgba.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
            c.cairo_set_line_width.argtypes = [ctypes.c_void_p, ctypes.c_double]
            c.cairo_move_to.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_double]
            c.cairo_line_to.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_double]
            c.cairo_curve_to.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
            c.cairo_arc.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
            return c
        except OSError:
            continue
    return None


def bake_with_tex(layout, seed, page, palette, outpath, dpi):
    """Bake using texlua and tools/preview.lua + pdftocairo."""
    texlua = find_binary("texlua")
    pdftocairo = find_binary("pdftocairo")
    if not (texlua and pdftocairo):
        return False

    with tempfile.TemporaryDirectory() as tmpdir:
        spec_file = os.path.join(tmpdir, "spec.lua")
        pdf_file = os.path.join(tmpdir, "flora.pdf")

        # Create a standard A4 layout specification
        width, height = 595.28, 841.89
        if layout == "left":
            text_x0, text_y0, text_x1, text_y1 = 156.0, 90.0, 538.0, 740.0
        elif layout == "right":
            text_x0, text_y0, text_x1, text_y1 = 57.0, 90.0, 439.0, 740.0
        elif layout == "centered":
            text_x0, text_y0, text_x1, text_y1 = 130.0, 90.0, 465.0, 740.0
        elif layout == "surround":
            text_x0, text_y0, text_x1, text_y1 = 90.0, 90.0, 505.0, 740.0
        else:  # title
            text_x0, text_y0, text_x1, text_y1 = 90.0, 110.0, 505.0, 730.0

        spec_content = f"""{{
  width = {width}, height = {height},
  text = {{ x0 = {text_x0}, y0 = {text_y0}, x1 = {text_x1}, y1 = {text_y1} }},
  header_y = 780.0,
  layout = "{layout}",
  page = {page},
  doc_seed = "{seed}",
}}
"""
        with open(spec_file, "w") as f:
            f.write(spec_content)

        settings = "fresh, noheader"
        if palette:
            settings += f", palette={{{palette}}}"

        cmd_preview = [
            texlua,
            os.path.join(ROOT, "tools", "preview.lua"),
            spec_file,
            str(seed),
            str(page),
            pdf_file,
            "-",
            settings,
        ]
        res = subprocess.run(cmd_preview, cwd=ROOT, capture_output=True, text=True)
        if res.returncode != 0:
            sys.stderr.write(f"preview.lua failed: {res.stderr or res.stdout}\n")
            return False

        out_prefix = os.path.splitext(outpath)[0]
        cmd_cairo = [
            pdftocairo,
            "-png",
            "-transp",
            "-singlefile",
            "-r",
            str(dpi),
            pdf_file,
            out_prefix,
        ]
        res2 = subprocess.run(cmd_cairo, cwd=ROOT, capture_output=True, text=True)
        if res2.returncode != 0:
            sys.stderr.write(f"pdftocairo failed: {res2.stderr}\n")
            return False

    return True


def bake_fallback(layout, seed, page, palette, outpath, dpi):
    """
    Generate a high-resolution transparent floral margin template when TeX Live
    is not installed, ensuring the document can still embed a valid baked asset.
    """
    cairo = get_cairo()
    scale = dpi / 72.0
    w_pt, h_pt = 595.28, 841.89
    w_px = int(round(w_pt * scale))
    h_px = int(round(h_pt * scale))

    if cairo:
        surf = cairo.cairo_image_surface_create(0, w_px, h_px)
        cr = cairo.cairo_create(surf)
        # Flip Y so coordinates match standard PDF/TeX space
        cairo.cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0)
        cairo.cairo_paint(cr)

        # Palette colors (Pilot iroshizuku ultramarine & antique gold tones)
        ink = (0.05, 0.11, 0.26, 0.85)
        blue = (0.08, 0.28, 0.78, 0.55)
        gold = (0.70, 0.56, 0.34, 0.75)

        # Draw margin vine gesture
        if layout in ("left", "split"):
            margin_x = 75.0 * scale
            cairo.cairo_set_source_rgba(cr, *ink)
            cairo.cairo_set_line_width(cr, 2.0 * scale)
            cairo.cairo_move_to(cr, margin_x, 50.0 * scale)
            cairo.cairo_curve_to(
                cr,
                margin_x + 25.0 * scale,
                h_px * 0.35,
                margin_x - 20.0 * scale,
                h_px * 0.65,
                margin_x,
                h_px - 60.0 * scale,
            )
            cairo.cairo_stroke(cr)

            # Leaves and blooms along the margin
            for y_frac in [0.2, 0.35, 0.5, 0.65, 0.8]:
                ly = h_px * y_frac
                cairo.cairo_set_source_rgba(cr, *blue)
                cairo.cairo_move_to(cr, margin_x, ly)
                cairo.cairo_curve_to(
                    cr,
                    margin_x + 35.0 * scale,
                    ly - 15.0 * scale,
                    margin_x + 40.0 * scale,
                    ly + 15.0 * scale,
                    margin_x,
                    ly,
                )
                cairo.cairo_fill(cr)
                # Gilt star ornament
                cairo.cairo_set_source_rgba(cr, *gold)
                cairo.cairo_arc(cr, margin_x + 12.0 * scale, ly, 4.0 * scale, 0, 2 * math.pi)
                cairo.cairo_fill(cr)

        elif layout == "right":
            margin_x = w_px - 75.0 * scale
            cairo.cairo_set_source_rgba(cr, *ink)
            cairo.cairo_set_line_width(cr, 2.0 * scale)
            cairo.cairo_move_to(cr, margin_x, 50.0 * scale)
            cairo.cairo_curve_to(
                cr,
                margin_x - 25.0 * scale,
                h_px * 0.35,
                margin_x + 20.0 * scale,
                h_px * 0.65,
                margin_x,
                h_px - 60.0 * scale,
            )
            cairo.cairo_stroke(cr)

            for y_frac in [0.2, 0.35, 0.5, 0.65, 0.8]:
                ly = h_px * y_frac
                cairo.cairo_set_source_rgba(cr, *blue)
                cairo.cairo_move_to(cr, margin_x, ly)
                cairo.cairo_curve_to(
                    cr,
                    margin_x - 35.0 * scale,
                    ly - 15.0 * scale,
                    margin_x - 40.0 * scale,
                    ly + 15.0 * scale,
                    margin_x,
                    ly,
                )
                cairo.cairo_fill(cr)
                cairo.cairo_set_source_rgba(cr, *gold)
                cairo.cairo_arc(cr, margin_x - 12.0 * scale, ly, 4.0 * scale, 0, 2 * math.pi)
                cairo.cairo_fill(cr)

        cairo.cairo_surface_write_to_png(surf, outpath.encode("utf-8"))
        cairo.cairo_destroy(cr)
        cairo.cairo_surface_destroy(surf)
        return True

    # Pillow fallback if cairo is unavailable
    try:
        from PIL import Image, ImageDraw

        img = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        margin_x = int(75.0 * scale) if layout != "right" else int(w_px - 75.0 * scale)
        draw.line([(margin_x, 50), (margin_x, h_px - 60)], fill=(13, 27, 66, 200), width=int(2 * scale))
        img.save(outpath, "PNG")
        return True
    except Exception as e:
        sys.stderr.write(f"Fallback generation error: {e}\n")
        return False


# The progress lines use a check mark, which a Windows console's default
# code page cannot encode.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def bake_item(layout, seed, page, palette, outdir, dpi):
    """Bake a single image asset."""
    os.makedirs(outdir, exist_ok=True)
    filename = f"flora-{layout}-s{seed}.png"
    outpath = os.path.join(outdir, filename)

    print(f"Baking {layout} (seed {seed}) -> {outpath} ...")
    success = bake_with_tex(layout, seed, page, palette, outpath, dpi)
    if not success:
        success = bake_fallback(layout, seed, page, palette, outpath, dpi)

    if success:
        print(f"  ✓ Saved {outpath}")
    else:
        sys.stderr.write(f"  ✗ Failed to bake {filename}\n")
    return success


def main():
    parser = argparse.ArgumentParser(description="Bake procedural flora into lightweight images.")
    parser.add_argument("--layout", choices=["left", "right", "split", "title", "surround", "centered"],
                        help="Specific layout to bake")
    parser.add_argument("--seed", default=1, type=int, help="Seed value")
    parser.add_argument("--page", default=1, type=int, help="Page number")
    parser.add_argument("--palette", default=None, help="Palette preset")
    parser.add_argument("--dpi", default=300, type=int, help="Resolution in DPI")
    parser.add_argument("--outdir", default=DEFAULT_OUTDIR, help="Output directory")
    parser.add_argument("--batch", action="store_true", help="Bake all standard layouts for seeds 1 and 3")

    args = parser.parse_args()

    if args.batch:
        layouts = ["left", "right", "title", "surround", "centered"]
        seeds = [1, 3]
        count = 0
        for s in seeds:
            for l in layouts:
                if bake_item(l, s, 1, None, args.outdir, args.dpi):
                    count += 1
        print(f"\nBatch complete: {count} images baked in {args.outdir}")
    else:
        layout = args.layout or "left"
        bake_item(layout, args.seed, args.page, args.palette, args.outdir, args.dpi)


if __name__ == "__main__":
    main()
