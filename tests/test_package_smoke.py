#!/usr/bin/env python3
"""Smoke tests — no JDownloader or browser required."""
from __future__ import annotations

import json
import re
import subprocess
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PackageLayoutTests(unittest.TestCase):
    def test_plugin_classes_present(self) -> None:
        needed = [
            ROOT / "plugin/plugins/hoster/AnkergamesNet.class",
            ROOT / "plugin/plugins/decrypter/AnkergamesNetCrawler.class",
            ROOT / "plugin/plugins/components/AnkergamesCdnRelay.class",
            ROOT / "core-patch/turnstile.html",
            ROOT / "core-patch/CloudflareTurnstileChallenge.class",
        ]
        for path in needed:
            self.assertTrue(path.is_file(), f"missing {path.relative_to(ROOT)}")

    def test_core_patch_has_relay_metas(self) -> None:
        html = (ROOT / "core-patch/turnstile.html").read_text(encoding="utf-8")
        for name in ("relayUrl", "gameUrl", "downloadId"):
            self.assertIn(f'name="{name}"', html)

    def test_companion_manifests(self) -> None:
        ff = json.loads((ROOT / "companion/firefox/manifest.json").read_text())
        ch = json.loads((ROOT / "companion/chromium/manifest.json").read_text())
        self.assertEqual(ff["version"], ch["version"])
        self.assertIn("icons", ff)
        self.assertIn("icons", ch)
        for size in ("16", "48", "128"):
            self.assertTrue((ROOT / "companion/chromium/icons" / f"icon{size}.png").is_file())
            self.assertTrue((ROOT / "companion/firefox/icons" / f"icon{size}.png").is_file())

    def test_no_account_login_in_sources(self) -> None:
        hoster = (ROOT / "src/jd/plugins/hoster/AnkergamesNet.java").read_text(encoding="utf-8")
        crawler = (ROOT / "src/jd/plugins/decrypter/AnkergamesNetCrawler.java").read_text(encoding="utf-8")
        self.assertNotIn("enablePremium", hoster)
        self.assertNotIn("void login(", hoster)
        self.assertNotIn("fetchAccountInfo", hoster)
        self.assertNotIn("AccountController", crawler)
        self.assertNotIn("hoster.login", crawler)

    def test_chromium_update_feed_xml(self) -> None:
        tree = ET.parse(ROOT / "updates/chromium.xml")
        root = tree.getroot()
        self.assertTrue(any("gupdate" in (el.tag or "") for el in [root, *root.iter()]))

    def test_firefox_update_feed_json(self) -> None:
        data = json.loads((ROOT / "updates/firefox.json").read_text())
        self.assertIn("addons", data)


class BuildPackagesTests(unittest.TestCase):
    def test_build_packages_script(self) -> None:
        script = ROOT / "companion/build-packages.sh"
        self.assertTrue(script.is_file())
        # Packaging needs zip; CRX pack is optional if no Chrome binary/display.
        subprocess.check_call(["bash", str(script)], cwd=str(ROOT / "companion"))
        ver = json.loads((ROOT / "companion/firefox/manifest.json").read_text())["version"]
        xpi = ROOT / f"companion/dist/jd-turnstile-companion-firefox-{ver}.xpi"
        zipp = ROOT / f"companion/dist/jd-turnstile-companion-chromium-{ver}.zip"
        self.assertTrue(xpi.is_file(), xpi)
        self.assertTrue(zipp.is_file(), zipp)
        with zipfile.ZipFile(xpi) as zf:
            names = zf.namelist()
            self.assertIn("manifest.json", names)
            self.assertIn("background.js", names)
        with zipfile.ZipFile(zipp) as zf:
            names = zf.namelist()
            self.assertIn("manifest.json", names)


class SanitizeLogicTests(unittest.TestCase):
    """Mirrors AnkergamesNet.sanitizePathName / buildArchiveFileName rules."""

    @staticmethod
    def sanitize(name: str) -> str:
        out = name.replace("/", "-").replace("\\", "-")
        out = out.replace("\u2044", "-").replace("\u2215", "-").replace("\uff0f", "-")
        out = re.sub(r"[\r\n\t]+", " ", out).strip()
        out = re.sub(r" {2,}", " ", out)
        return out

    @staticmethod
    def archive_name(slug: str | None, title: str | None) -> str:
        base = slug or title or "ankergames-download"
        base = SanitizeLogicTests.sanitize(base)
        if not base.lower().endswith(".zip"):
            base = base + ".zip"
        return base

    def test_slash_in_title(self) -> None:
        self.assertEqual(self.sanitize("Disney/Pixar Cars"), "Disney-Pixar Cars")

    def test_archive_adds_zip(self) -> None:
        self.assertEqual(self.archive_name("silver-pines", "Silver Pines"), "silver-pines.zip")


if __name__ == "__main__":
    unittest.main()
