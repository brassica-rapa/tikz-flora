#!/usr/bin/env python3
"""
tests/test_baked.py: Unit tests for the baked flora feature.
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import bake  # noqa: E402


class TestBakedFlora(unittest.TestCase):
    def test_find_binary(self):
        """find_binary should find python3 and texlua/pdftocairo if available."""
        p = bake.find_binary("python3")
        self.assertIsNotNone(p)
        self.assertTrue(os.path.exists(p))

    def test_bake_item_single(self):
        """Test baking a single layout and seed producing a valid PNG."""
        with tempfile.TemporaryDirectory() as tmpdir:
            success = bake.bake_item("left", 5, 1, None, tmpdir, 150)
            self.assertTrue(success)
            target = os.path.join(tmpdir, "flora-left-s5.png")
            self.assertTrue(os.path.isfile(target))
            with open(target, "rb") as f:
                sig = f.read(8)
                self.assertEqual(sig, b"\x89PNG\r\n\x1a\n")
                length, chunk_type = struct.unpack(">I4s", f.read(8))
                self.assertEqual(chunk_type, b"IHDR")
                width, height = struct.unpack(">II", f.read(8))
                self.assertGreater(width, 500)
                self.assertGreater(height, 500)

    def test_compile_auto_bakes_and_caches_exact_open_space(self):
        """With baked=true, verify that lualatex --shell-escape computes flowers for the exact page open space,
        bakes them to flora-cache/, embeds the PNG, and reuses it on pass 2."""
        texlua = shutil.which("texlua")
        lualatex = shutil.which("lualatex")
        pdftocairo = shutil.which("pdftocairo")
        if not (texlua and lualatex and pdftocairo):
            self.skipTest("TeX environment and pdftocairo required for auto-baking integration test")

        with tempfile.TemporaryDirectory() as tmpdir:
            doc_tex = os.path.join(tmpdir, "test_doc.tex")
            with open(doc_tex, "w") as f:
                f.write(r"""\documentclass{article}
\usepackage{tikzflora}
\florasetup{layout=left, seed=42, baked=true}
\begin{document}
This is a test of procedural flower generation with exact open space.
\end{document}
""")
            # A cache inside the temp dir, and the platform's own path
            # separator (";" on Windows), with forward slashes TeX accepts.
            cache = os.path.join(tmpdir, "texmf-cache").replace(os.sep, "/")
            tex_dir = os.path.join(ROOT, "tex").replace(os.sep, "/")
            env = dict(
                os.environ,
                TEXINPUTS=f"{tex_dir}//{os.pathsep}",
                TEXMFCACHE=cache,
                TEXMFVAR=cache,
            )
            # Pass 1: should compute flowers and bake image into flora-cache/
            res1 = subprocess.run(
                ["lualatex", "--shell-escape", "--interaction=nonstopmode", doc_tex],
                cwd=tmpdir,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res1.returncode, 0, f"Compilation failed: {res1.stderr or res1.stdout}")
            pdf_path = os.path.join(tmpdir, "test_doc.pdf")
            self.assertTrue(os.path.isfile(pdf_path))
            pdf_size = os.path.getsize(pdf_path)
            # PDF size should be compact (~1-2MB max, not 15-20MB of raw vectors)
            self.assertLess(pdf_size, 3 * 1024 * 1024, "Output PDF should be lightweight")

            # Check that flora-cache contains the hashed PNG
            cache_dir = os.path.join(tmpdir, "flora-cache")
            self.assertTrue(os.path.isdir(cache_dir))
            cached_files = [f for f in os.listdir(cache_dir) if f.startswith("flora-left-s42-p1-") and f.endswith(".png")]
            self.assertEqual(len(cached_files), 1, "Exactly one cached PNG matching seed 42 should exist")

            # Pass 2: should reuse cached image (instant cache hit)
            res2 = subprocess.run(
                ["lualatex", "--interaction=nonstopmode", doc_tex],
                cwd=tmpdir,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res2.returncode, 0, "Pass 2 compile should succeed with cached image")


if __name__ == "__main__":
    unittest.main()
