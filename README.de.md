<p align="center">
  <img src="companion/assets/logo.png" width="180" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  <b>AnkerGames-Downloads, die in JD wirklich laufen</b><br/>
  Manuelle Installation · Kein MyJD · Kein AnkerGames-Login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Plugin_ZIP-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download Plugin ZIP" /></a>
  &nbsp;
  <a href="https://jdownloader.org/jdownloader2"><img src="https://img.shields.io/badge/⬇_JDownloader_2-1a5f7a?style=for-the-badge&labelColor=0b1220" alt="Download JDownloader 2" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square&label=release" alt="Release" />
  <img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" />
  <img src="https://img.shields.io/badge/Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
  &nbsp;·&nbsp; <a href="README.md">English</a>
</p>

---

### Wozu?

[ankergames.net](https://ankergames.net) steckt hinter Cloudflare. Der Java-Client von JD wird blockiert.  
Dieses Paket liefert **JD-Plugin** + **Browser-Erweiterung**: Turnstile im echten Browser, Datei per localhost an JD.

> Inoffiziell · nicht verbunden mit AppWork / JDownloader / AnkerGames

---

### Installation in 4 Schritten

| | Schritt | Aktion |
|:---:|:--------|:-------|
| 0️⃣ | **Kein JD?** | [JDownloader 2 herunterladen](https://jdownloader.org/jdownloader2) |
| 1️⃣ | **Dieses ZIP** | [Download](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip) & entpacken |
| 2️⃣ | **Plugin** | JD-Ordner finden → Dateien kopieren → `Core.jar` patchen |
| 3️⃣ | **Browser** | Companion in Chrome/Vivaldi/… oder Firefox Dev laden |
| 4️⃣ | **Nutzen** | Spiel-URL in JD → Captcha lösen → **Tab offen lassen** |

<details>
<summary><b>📁 Schritt 2 — JD-Ordner finden (Pathfinder)</b></summary>

<br/>

Bei jedem PC anders (Installer vs Portable). Du brauchst den Ordner mit **`JDownloader.jar`**.

| Name | Bedeutung | Beispiel |
|------|-----------|----------|
| 🏠 **JD-Root** | `JDownloader.jar` + `Core.jar` | `C:\JDownloader\` · `~/.jd/` |
| 📦 **Plugin-Ordner** | Unterordner `jd/plugins/` | `…/jd/plugins/` |

**Am einfachsten — Pathfinder aus dem ZIP:**

| OS | Befehl |
|----|--------|
| 🪟 Windows | `plugin/find-jd-home.bat` doppelklicken |
| 🐧 Linux / 🍎 macOS | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

Zeigt **JD-Root** und **Plugin-Ordner**. Mehrere Treffer → die Installation deiner Verknüpfung nehmen.

<details>
<summary>Stattdessen selbst suchen</summary>

1. Nach `JDownloader.jar` suchen (`Win+S`)  
2. Rechtsklick → **Dateipfad öffnen** → das ist der JD-Root  
3. `jd` → `plugins` öffnen → Plugin-Ordner  

</details>

<details>
<summary>❓ Pathfinder findet nichts</summary>

1. JDownloader einmal starten  
2. Rechtsklick auf Verknüpfung → **Dateipfad öffnen**  
3. Portable: Desktop / Downloads / USB / anderes Laufwerk prüfen  
4. Oder nach `Core.jar` suchen (muss neben `JDownloader.jar` liegen)  
5. Plugins nach `<JD-Root>/jd/plugins/` kopieren  

</details>

</details>

<details>
<summary><b>🧩 Schritt 2 — Plugin + Core-Patch installieren</b></summary>

<br/>

1. **JD komplett beenden**  
2. In **deinen** Plugin-Ordner kopieren:

| Aus dem ZIP | Ziel |
|-------------|------|
| `plugin/plugins/hoster/*` | `<JD-Root>/jd/plugins/hoster/` |
| `plugin/plugins/decrypter/*` | `<JD-Root>/jd/plugins/decrypter/` |
| `plugin/plugins/components/*` | `<JD-Root>/jd/plugins/components/` |

✅ Fertig bei `<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`

3. **`Core.jar`** im JD-Root (neben `JDownloader.jar`) mit 7-Zip patchen — **zuerst Backup**:

| In `Core.jar` | Ersetzen durch |
|---------------|----------------|
| `…/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `…/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. JD starten  

<details>
<summary>Optional: Kopier-Skript</summary>

```bash
cd plugin
JD_HOME="/pfad/zum/JD-Root" ./install.sh   # Linux / macOS
# Windows: install.bat
```

</details>

</details>

<details>
<summary><b>🌐 Schritt 3 — Browser-Companion</b></summary>

<br/>

Denselben Browser nutzen, den JD für Captchas öffnet.

| Browser | So |
|---------|----|
| 🟢 Chrome / Vivaldi / Brave / Edge | `chrome://extensions` → Entwicklermodus AN → **Entpackt laden** → `companion/chromium/` |
| 🦊 Firefox | Nur **Dev Edition / Nightly** → `about:config` → `xpinstall.signatures.required` = **false** → `companion/dist/jd-turnstile-companion-firefox-*.xpi` installieren |

</details>

<details>
<summary><b>▶️ Schritt 4 — Benutzung</b></summary>

<br/>

| # | Aktion |
|---|--------|
| 1 | In JD z. B. `https://ankergames.net/game/…` einfügen |
| 2 | Download starten → **Turnstile** im Browser lösen |
| 3 | **AnkerGames-Tab offen lassen**, bis JD fertig ist |

Kein AnkerGames-Konto in JD. Kein MyJDownloader.

```text
Turnstile (du) → Companion holt CDN → localhost → JD speichert
```

</details>

<details>
<summary><b>🛠️ Probleme</b></summary>

<br/>

| Problem | Lösung |
|---------|--------|
| Pathfinder leer | Oben „Pathfinder findet nichts“ aufklappen |
| Plugin fehlt in JD | Dateien unter `…/jd/plugins/…` + Core-Patch |
| Erweiterung fehlt | Entwicklermodus an · neu laden |
| Firefox „nicht verifiziert“ | Dev Edition / Nightly + Signaturen = false |
| JD bei 0 B | AnkerGames-Tab offen lassen |
| Browser speichert die ZIP | `*.dlproxy.uk` nicht öffnen · Companion neu laden |

</details>

<details>
<summary><b>👨‍💻 Entwickler</b></summary>

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```

</details>
