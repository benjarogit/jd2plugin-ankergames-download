//jDownloader - Downloadmanager
//Copyright (C) 2009  JD-Team support@jdownloader.org
//
//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.
package jd.plugins.hoster;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import org.appwork.storage.TypeRef;
import org.appwork.utils.StringUtils;
import org.appwork.utils.encoding.Base64;
import org.appwork.utils.formatter.SizeFormatter;
import org.appwork.utils.os.CrossSystem;
import org.appwork.utils.swing.EDTRunner;
import org.appwork.utils.swing.windowmanager.WindowManager.FrameState;
import org.jdownloader.captcha.v2.challenge.cloudflareturnstile.AbstractCloudflareTurnstileCaptcha;
import org.jdownloader.plugins.controller.LazyPlugin;

import jd.gui.swing.jdgui.JDGui;

import jd.PluginWrapper;
import jd.http.Browser;
import jd.http.Browser.BlockedByException;
import jd.http.Cookies;
import jd.http.URLConnectionAdapter;
import jd.plugins.components.AnkergamesCdnRelay;
import jd.plugins.components.AnkergamesTurnstileChallenge;
import jd.nutils.encoding.Encoding;
import jd.parser.Regex;
import jd.plugins.Account;
import jd.plugins.DownloadLink;
import jd.plugins.DownloadLink.AvailableStatus;
import jd.plugins.HostPlugin;
import jd.plugins.LinkStatus;
import jd.plugins.PluginException;
import jd.plugins.PluginForHost;

@HostPlugin(revision = "$Revision$", interfaceVersion = 3, names = {}, urls = {})
public class AnkergamesNet extends PluginForHost {
    public AnkergamesNet(PluginWrapper wrapper) {
        super(wrapper);
        /* Guest + browser companion only — no AnkerGames account in JD. */
    }

    @Override
    public Browser createNewBrowserInstance() {
        final Browser br = super.createNewBrowserInstance();
        br.setFollowRedirects(true);
        /*
         * Keep JD's default site UA for ankergames.net HTML. A Firefox/158 UA made JD send
         * Sec-Fetch-* and the treasure-box page then never finished loading (no captcha).
         * Avoid brotli — treasure pages have hung mid-body with Content-Encoding: br.
         */
        br.getHeaders().put("Accept-Encoding", "gzip, deflate");
        return br;
    }

    @Override
    public LazyPlugin.FEATURE[] getFeatures() {
        return new LazyPlugin.FEATURE[] {};
    }

    @Override
    public String getAGBLink() {
        return "https://" + getHost() + "/page/about";
    }

    public static List<String[]> getPluginDomains() {
        final List<String[]> ret = new ArrayList<String[]>();
        // each entry in List<String[]> will result in one PluginForHost, Plugin.getHost() will return String[0]->main domain
        ret.add(new String[] { "ankergames.net" });
        return ret;
    }

    public static String[] getAnnotationNames() {
        return buildAnnotationNames(getPluginDomains());
    }

    @Override
    public String[] siteSupportedNames() {
        return buildSupportedNames(getPluginDomains());
    }

    /**
     * Treasure-box signed URLs and final file tokens. <br>
     * Download requires Cloudflare Turnstile solved via JD captcha UI (BrowserSolver).
     */
    private static final Pattern PATTERN_DOWNLOAD      = Pattern.compile("/download/([A-Za-z0-9=_\\-]+)/([a-f0-9]{32,})/?");
    private static final Pattern PATTERN_DOWNLOAD_FILE = Pattern.compile("/download-file/([a-f0-9]+)/?");
    /** Fallback Turnstile sitekey observed on download/"Opening Treasure Box" pages (2026-10). */
    public static final String   TURNSTILE_SITEKEY     = "0x4AAAAAABL9QVQPEjEo2nnS";
    /**
     * Only for CDN openDownload (cloneBrowser). Do not set this as the site-wide UA — Firefox/158
     * made JD send Sec-Fetch-* and the treasure-box HTML load stalled (no captcha dialog).
     */
    private static final String  CDN_UA                = "Mozilla/5.0 (X11; Linux x86_64; rv:158.0) Gecko/20100101 Firefox/158.0";
    private static final String  PROPERTY_DIRECTURL    = "directurl";
    private static final String  PROPERTY_CDN_UA       = "cdn_user_agent";
    private static final String  PROPERTY_CDN_OPENED   = "cdn_opened_in_browser";
    private static final String  PROPERTY_FILE_TOKEN   = "file_token";
    /** Game page URL — used to mint a fresh signed /download/ ticket before Turnstile. */
    public static final String   PROPERTY_GAME_URL     = "ankergames_game_url";
    public static final String   PROPERTY_DOWNLOAD_ID  = "ankergames_download_id";
    private String               freshCsrfToken        = null;

    /**
     * Titles like "Disney/Pixar …" become folder names via Packagizer. JD maps "/" to U+2044
     * which still triggers INVALID_DESTINATION — replace path separators up front.
     */
    public static String sanitizePathName(final String name) {
        if (StringUtils.isEmpty(name)) {
            return name;
        }
        String out = name;
        out = out.replace('/', '-');
        out = out.replace('\\', '-');
        out = out.replace('\u2044', '-'); /* fraction slash */
        out = out.replace('\u2215', '-'); /* division slash */
        out = out.replace('\uFF0F', '-'); /* fullwidth solidus */
        out = out.replaceAll("[\\r\\n\\t]+", " ").trim();
        out = out.replaceAll(" {2,}", " ");
        return out;
    }

    /**
     * Packagizer creates {@code Downloads/<packageName>/}. If the link name equals that folder
     * name (no extension), JD refuses with INVALID_DESTINATION ("folder with name of this file
     * already exists"). Always give archives a {@code .zip} name derived from the URL slug.
     */
    public static String buildArchiveFileName(final String slug, final String title) {
        String base = slug;
        if (StringUtils.isEmpty(base)) {
            base = title;
        }
        base = sanitizePathName(base);
        if (StringUtils.isEmpty(base)) {
            base = "ankergames-download";
        }
        base = base.replace(' ', '-');
        base = base.replaceAll("-+", "-");
        if (!base.toLowerCase().endsWith(".zip") && !base.toLowerCase().endsWith(".rar") && !base.toLowerCase().endsWith(".7z")) {
            base = base + ".zip";
        }
        return base;
    }

    public static String[] getAnnotationUrls() {
        final List<String> ret = new ArrayList<String>();
        for (final String[] domains : getPluginDomains()) {
            ret.add("https?://(?:www\\.)?" + buildHostsPatternPart(domains) + "(" + PATTERN_DOWNLOAD.pattern() + "|" + PATTERN_DOWNLOAD_FILE.pattern() + ")");
        }
        return ret.toArray(new String[0]);
    }

    @Override
    public String getLinkID(final DownloadLink link) {
        final String fid = getFID(link);
        if (fid != null) {
            return this.getHost() + "://" + fid;
        } else {
            return super.getLinkID(link);
        }
    }

    private String getFID(final DownloadLink link) {
        final String fileToken = getDownloadFileToken(link);
        if (fileToken != null) {
            return fileToken;
        }
        final String payload = new Regex(link.getPluginPatternMatcher(), PATTERN_DOWNLOAD).getMatch(0);
        if (payload != null) {
            final String downloadId = getDownloadIdFromPayload(payload);
            if (downloadId != null) {
                return downloadId;
            }
            return payload;
        }
        return null;
    }

    private String getDownloadFileToken(final DownloadLink link) {
        String token = link.getStringProperty(PROPERTY_FILE_TOKEN);
        if (token != null) {
            return token;
        }
        token = new Regex(link.getPluginPatternMatcher(), PATTERN_DOWNLOAD_FILE).getMatch(0);
        return token;
    }

    /** Decode signed payload JSON: {"download_id":6677,"user_id":null,...} */
    private String getDownloadIdFromPayload(final String payloadB64) {
        try {
            final byte[] decoded = Base64.decode(payloadB64);
            if (decoded == null) {
                return null;
            }
            final String json = new String(decoded);
            return new Regex(json, "\"download_id\"\\s*:\\s*(\\d+)").getMatch(0);
        } catch (final Throwable e) {
            logger.log(e);
            return null;
        }
    }

    @Override
    public boolean isResumeable(final DownloadLink link, final Account account) {
        return true;
    }

    public int getMaxChunks(final DownloadLink link, final Account account) {
        /* Single connection — multi-chunk Range requests trip the CDN Cloudflare WAF. */
        return 1;
    }

    @Override
    public AvailableStatus requestFileInformation(final DownloadLink link) throws Exception {
        return requestFileInformation(link, false);
    }

    private AvailableStatus requestFileInformation(final DownloadLink link, final boolean isDownload) throws Exception {
        this.setBrowserExclusive();
        final String url = link.getPluginPatternMatcher();
        if (new Regex(url, PATTERN_DOWNLOAD_FILE).patternFind()) {
            if (!link.isNameSet()) {
                link.setName(getDownloadFileToken(link));
            }
            /* Final token URLs need Turnstile before they resolve — skip deep check during availablecheck. */
            return AvailableStatus.TRUE;
        }
        br.getPage(url);
        if (br.getHttpConnection().getResponseCode() == 404) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND);
        } else if (isExpiredDownloadPage(br)) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND, "Download link expired — re-add from the game page");
        } else if (br.containsHTML("(?i)download (link )?(expired|invalid)|link has expired|Invalid download")) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND);
        }
        parseTreasurePageFileInfo(link, br);
        final String fileToken = extractDownloadFileToken(br);
        if (fileToken != null) {
            link.setProperty(PROPERTY_FILE_TOKEN, fileToken);
        }
        return AvailableStatus.TRUE;
    }

    public static void parseTreasurePageFileInfo(final DownloadLink link, final Browser br) {
        String title = br.getRegex("<h1[^>]*>\\s*([^<]+?)\\s*</h1>").getMatch(0);
        if (title == null) {
            title = br.getRegex("<title>\\s*(.*?)\\s*(?:\\|\\s*AnkerGames| - AnkerGames)\\s*</title>").getMatch(0);
        }
        if (title != null) {
            title = Encoding.htmlDecode(title).trim();
            title = title.replaceFirst("(?i)^Opening Treasure Box\\s*-?\\s*", "");
            title = sanitizePathName(title);
            if (!StringUtils.isEmpty(title) && !title.equalsIgnoreCase("Opening Treasure Box")) {
                /* Keep existing final name if crawler already set a .zip; only fill gaps. */
                if (!link.isNameSet() || !link.getName().contains(".")) {
                    link.setName(buildArchiveFileName(null, title));
                }
            }
        }
        final String filesize = br.getRegex("(\\d+(?:\\.\\d+)?\\s*(?:KB|MB|GB|TB))\\s*(?:File Size|</)").getMatch(0);
        if (filesize != null) {
            link.setDownloadSize(SizeFormatter.getSize(filesize));
        }
    }

    @Override
    public void handleFree(final DownloadLink link) throws Exception, PluginException {
        handleDownload(link);
    }

    private void handleDownload(final DownloadLink link) throws Exception {
        if (!attemptStoredDownloadurlDownload(link)) {
            /*
             * Always mint a fresh treasure-box + fileToken immediately before Turnstile. Tickets from
             * linkgrab time are often already 410 Gone by the time the user finishes the captcha.
             */
            final String fileToken = refreshTreasureFileToken(link);
            if (StringUtils.isEmpty(fileToken)) {
                throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Missing file token after refresh");
            }
            /*
             * Localhost relay: Companion fetches CDN with browser TLS and pushes bytes here; JD
             * downloads from 127.0.0.1 so AnkerGames only sees the browser.
             */
            final AnkergamesCdnRelay relay = AnkergamesCdnRelay.start(getLogger());
            try {
                final String relayBase = relay.getBaseUrl();
                final String siteKey = findTurnstileSiteKey(br);
                final String treasureUrl = link.getPluginPatternMatcher();
                final String fileTokenFinal = fileToken;
                final String gameUrlFinal = link.getStringProperty(PROPERTY_GAME_URL);
                final String downloadIdFinal = link.getStringProperty(PROPERTY_DOWNLOAD_ID);
                final AnkergamesTurnstileChallenge challenge = new AnkergamesTurnstileChallenge(this, siteKey) {
                    @Override
                    public String getSiteUrl() {
                        if (StringUtils.isNotEmpty(gameUrlFinal)) {
                            return gameUrlFinal;
                        }
                        return treasureUrl;
                    }

                    @Override
                    public String getFileToken() {
                        return fileTokenFinal;
                    }

                    @Override
                    public String getGameUrl() {
                        return gameUrlFinal;
                    }

                    @Override
                    public String getDownloadId() {
                        return downloadIdFinal;
                    }

                    @Override
                    public String getRelayUrl() {
                        return relayBase;
                    }
                };
                final String captchaResult = this.handleCaptchaChallenge(link, challenge);
                final CdnCapture cdn = parseCdnCapture(captchaResult);
                final String dllink;
                if (cdn != null && StringUtils.equalsIgnoreCase(cdn.via, "relay")) {
                    /*
                     * Companion fetched CDN with real browser TLS (Cloudflare sees Firefox/Chrome
                     * JA4, not Java). JD only downloads from localhost — never hits dlproxy.
                     */
                    dllink = relay.getFileUrl();
                    /* Browser tab closes after pipe start — bring JD forward so progress is visible. */
                    bringJdToFront();
                } else if (cdn != null && StringUtils.isNotEmpty(cdn.url) && StringUtils.startsWithCaseInsensitive(cdn.via, "browser")) {
                    link.removeProperty(PROPERTY_DIRECTURL);
                    throw new PluginException(LinkStatus.ERROR_FATAL, "CDN download started in browser (update Companion to 1.2+ for JD-managed relay).");
                } else if (cdn != null && StringUtils.equalsIgnoreCase(cdn.via, "error")) {
                    throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Companion relay error — reload companion 1.2.8+", 1 * 60 * 1000l);
                } else if (cdn != null && StringUtils.isNotEmpty(cdn.url) && StringUtils.containsIgnoreCase(cdn.url, "dlproxy.")) {
                    /*
                     * Never open dlproxy with JD's Java HTTP client — Cloudflare blocks Java TLS
                     * fingerprints even when the User-Agent claims to be Firefox (JD-Devs).
                     */
                    throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Companion must stream CDN via relay (via=relay). Reload JD Turnstile Companion.", 1 * 60 * 1000l);
                } else if (looksLikeDirectHttpUrl(captchaResult) && StringUtils.containsIgnoreCase(captchaResult, "dlproxy.")) {
                    throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Companion must stream CDN via relay (via=relay). Reload JD Turnstile Companion.", 1 * 60 * 1000l);
                } else if (cdn != null && StringUtils.isNotEmpty(cdn.url)) {
                    dllink = cdn.url;
                    if (StringUtils.isNotEmpty(cdn.userAgent)) {
                        link.setProperty(PROPERTY_CDN_UA, cdn.userAgent);
                    }
                } else if (looksLikeDirectHttpUrl(captchaResult)) {
                    dllink = captchaResult.trim();
                } else {
                    dllink = resolveFinalDownloadUrl(fileToken, captchaResult);
                }
                if (StringUtils.isEmpty(dllink)) {
                    throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT);
                }
                if (StringUtils.containsIgnoreCase(dllink, "dlproxy.")) {
                    throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Refusing Java→CDN (Cloudflare). Use Companion relay.", 1 * 60 * 1000l);
                }
                final Browser brc = br.cloneBrowser();
                final boolean resume;
                final int chunks;
                if (dllink.startsWith("http://127.0.0.1")) {
                    /* Relay may wait for companion CDN fetch — do not use the default 60s read timeout. */
                    brc.setReadTimeout(10 * 60 * 1000);
                    brc.setConnectTimeout(30 * 1000);
                    /* Localhost pipe is single-shot; Range/resume would break the queue. */
                    resume = false;
                    chunks = 1;
                } else {
                    prepareCdnRequestHeaders(brc, link, dllink);
                    resume = this.isResumeable(link, null);
                    chunks = this.getMaxChunks(link, null);
                }
                try {
                    dl = jd.plugins.BrowserAdapter.openDownload(brc, link, dllink, resume, chunks);
                    handleConnectionErrors(brc, dl.getConnection());
                } catch (final BlockedByException e) {
                    logger.log(e);
                    link.removeProperty(PROPERTY_DIRECTURL);
                    throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "CDN blocked Java client — Companion relay required", 2 * 60 * 1000l);
                }
                if (!StringUtils.containsIgnoreCase(dllink, "dlproxy.") && !dllink.startsWith("http://127.0.0.1")) {
                    link.setProperty(PROPERTY_DIRECTURL, dl.getConnection().getURL().toExternalForm());
                }
                dl.startDownload();
            } finally {
                /* Keep relay alive until download thread finished reading — close after startDownload returns. */
                try {
                    relay.close();
                } catch (final Exception ignore) {
                }
            }
            return;
        }
        dl.startDownload();
    }

    private static class CdnCapture {
        private String url;
        private String userAgent;
        private String via;
    }

    /**
     * Companion returns JSON {@code {"url":"...","userAgent":"...","via":"browser"}}.
     */
    private CdnCapture parseCdnCapture(final String captchaResult) {
        if (StringUtils.isEmpty(captchaResult)) {
            return null;
        }
        final String raw = captchaResult.trim();
        if (!raw.startsWith("{")) {
            return null;
        }
        try {
            final Map<String, Object> map = restoreFromString(raw, TypeRef.MAP);
            final CdnCapture out = new CdnCapture();
            final Object urlObj = map.get("url");
            if (urlObj != null) {
                out.url = urlObj.toString();
            }
            final Object uaObj = map.get("userAgent");
            if (uaObj != null) {
                out.userAgent = uaObj.toString();
            }
            final Object viaObj = map.get("via");
            if (viaObj != null) {
                out.via = viaObj.toString();
            }
            return out;
        } catch (final Throwable e) {
            logger.log(e);
            return null;
        }
    }

    private void prepareCdnRequestHeaders(final Browser browser, final DownloadLink link, final String dllink) {
        final String ua = link.getStringProperty(PROPERTY_CDN_UA, CDN_UA);
        browser.getHeaders().put("User-Agent", StringUtils.isNotEmpty(ua) ? ua : CDN_UA);
        browser.getHeaders().put("Accept", "*/*");
        browser.getHeaders().put("Accept-Language", "de,en-US;q=0.9,en;q=0.8");
        browser.getHeaders().put("Referer", "https://" + getHost() + "/");
        browser.getHeaders().put("Origin", "https://" + getHost());
        /* Never set Sec-Fetch-* on the shared site browser — it broke treasure-page loads. */
    }

    private void openCdnInBrowserOnce(final DownloadLink link, final String dllink) {
        if (link.getBooleanProperty(PROPERTY_CDN_OPENED, false)) {
            return;
        }
        link.setProperty(PROPERTY_CDN_OPENED, true);
        try {
            CrossSystem.openURL(dllink);
        } catch (final Throwable e) {
            logger.log(e);
        }
    }

    /**
     * Treasure-box pages embed the file URL inside Alpine/JS as either plain or escaped form:
     * {@code /download-file/TOKEN} or {@code \/download-file\/TOKEN}.
     */
    private String extractDownloadFileToken(final Browser br) {
        String token = br.getRegex("download-file(?:\\\\/|/)([a-f0-9]{16,})").getMatch(0);
        if (token == null) {
            token = br.getRegex("/download-file/([a-f0-9]+)").getMatch(0);
        }
        return token;
    }

    private String findTurnstileSiteKey(final Browser br) {
        String siteKey = br.getRegex("data-sitekey\\s*=\\s*\"(" + AbstractCloudflareTurnstileCaptcha.apiKeyRegex + ")\"").getMatch(0);
        if (siteKey == null) {
            siteKey = br.getRegex("(?:sitekey|SITE_KEY)\\s*[:=]\\s*[\"'](" + AbstractCloudflareTurnstileCaptcha.apiKeyRegex + ")[\"']").getMatch(0);
        }
        if (siteKey == null) {
            siteKey = TURNSTILE_SITEKEY;
        }
        return siteKey;
    }

    /**
     * Prefer JSON link endpoint (same as website "Copy download link"), fall back to download-file URL with Turnstile query.
     */
    /**
     * Re-run generate-download-url from the game page so Turnstile + /link use a live file ticket.
     */
    private String refreshTreasureFileToken(final DownloadLink link) throws Exception {
        String gameUrl = link.getStringProperty(PROPERTY_GAME_URL);
        String downloadId = link.getStringProperty(PROPERTY_DOWNLOAD_ID);
        if (downloadId == null) {
            final String payload = new Regex(link.getPluginPatternMatcher(), PATTERN_DOWNLOAD).getMatch(0);
            downloadId = getDownloadIdFromPayload(payload);
        }
        if (StringUtils.isEmpty(downloadId)) {
            /* Last resort: try existing pattern URL once. */
            requestFileInformation(link, true);
            String fileToken = extractDownloadFileToken(br);
            if (fileToken == null) {
                fileToken = getDownloadFileToken(link);
            }
            if (fileToken != null) {
                link.setProperty(PROPERTY_FILE_TOKEN, fileToken);
            }
            return fileToken;
        }
        if (StringUtils.isEmpty(gameUrl)) {
            gameUrl = "https://" + getHost() + "/";
        }
        br.getPage(gameUrl);
        if (br.getHttpConnection().getResponseCode() == 404) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND);
        }
        ensureLaravelSession(br);
        Map<String, Object> entries = requestGenerateDownloadUrl(br, downloadId);
        if (isCsrfMismatch(entries)) {
            ensureLaravelSession(br);
            entries = requestGenerateDownloadUrl(br, downloadId);
        }
        if (!Boolean.TRUE.equals(entries.get("success"))) {
            final Object error = entries.get("error");
            final Object message = entries.get("message");
            final String msg = error != null ? error.toString() : (message != null ? message.toString() : "generate-download-url failed");
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, msg, 60 * 1000l);
        }
        final String downloadUrl = (String) entries.get("download_url");
        if (StringUtils.isEmpty(downloadUrl)) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT);
        }
        link.setPluginPatternMatcher(downloadUrl);
        link.removeProperty(PROPERTY_FILE_TOKEN);
        br.getPage(downloadUrl);
        if (isExpiredDownloadPage(br)) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND, "Fresh download link expired immediately");
        }
        parseTreasurePageFileInfo(link, br);
        final String fileToken = extractDownloadFileToken(br);
        if (fileToken == null) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "No /download-file/ token on treasure page");
        }
        link.setProperty(PROPERTY_FILE_TOKEN, fileToken);
        link.setProperty(PROPERTY_DOWNLOAD_ID, downloadId);
        return fileToken;
    }

    private void ensureLaravelSession(final Browser br) throws Exception {
        final Browser brc = br.cloneBrowser();
        brc.getHeaders().put("Accept", "application/json");
        brc.getHeaders().put("X-Requested-With", "XMLHttpRequest");
        brc.getHeaders().put("Referer", br.getURL() != null ? br.getURL() : ("https://" + this.getHost() + "/"));
        brc.getPage("/csrf-token");
        br.setCookies(brc.getCookies(br.getHost()));
        final String html = brc.getRequest().getHtmlCode();
        if (StringUtils.isNotEmpty(html) && html.startsWith("{")) {
            final Map<String, Object> csrfJson = restoreFromString(html, TypeRef.MAP);
            final Object token = csrfJson.get("token");
            if (token != null) {
                this.freshCsrfToken = token.toString();
            }
        }
    }

    private Map<String, Object> requestGenerateDownloadUrl(final Browser br, final String downloadId) throws Exception {
        final Browser brc = br.cloneBrowser();
        brc.setAllowedResponseCodes(419, 422, 429);
        brc.getHeaders().put("Accept", "application/json");
        brc.getHeaders().put("Content-Type", "application/json");
        brc.getHeaders().put("X-Requested-With", "XMLHttpRequest");
        brc.getHeaders().put("Origin", "https://" + br.getHost());
        brc.getHeaders().put("Referer", br.getURL());
        applyLaravelCsrfHeaders(br, brc);
        brc.postPageRaw("/generate-download-url/" + downloadId, "{}");
        br.setCookies(brc.getCookies(br.getHost()));
        final String html = brc.getRequest().getHtmlCode();
        if (StringUtils.isEmpty(html) || !html.startsWith("{")) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Unexpected generate-download-url response");
        }
        return restoreFromString(html, TypeRef.MAP);
    }

    private void applyLaravelCsrfHeaders(final Browser source, final Browser target) throws Exception {
        String xsrfCookie = source.getCookie(source.getHost(), "XSRF-TOKEN", Cookies.NOTDELETEDPATTERN);
        if (xsrfCookie == null) {
            xsrfCookie = source.getCookie(source.getHost(), "XSRF-TOKEN");
        }
        if (xsrfCookie != null) {
            String decoded = xsrfCookie;
            try {
                decoded = java.net.URLDecoder.decode(xsrfCookie, "UTF-8");
            } catch (final Throwable e) {
                logger.log(e);
            }
            target.getHeaders().put("X-XSRF-TOKEN", decoded);
            target.getHeaders().put("X-CSRF-TOKEN", this.freshCsrfToken != null ? this.freshCsrfToken : decoded);
            return;
        }
        if (this.freshCsrfToken != null) {
            target.getHeaders().put("X-CSRF-TOKEN", this.freshCsrfToken);
            return;
        }
        String metaCsrf = source.getRegex("name=\"csrf-token\"\\s*content=\"([^\"]+)\"").getMatch(0);
        if (metaCsrf != null) {
            target.getHeaders().put("X-CSRF-TOKEN", metaCsrf);
            return;
        }
        throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Missing CSRF token");
    }

    private boolean isCsrfMismatch(final Map<String, Object> entries) {
        if (entries == null || entries.get("message") == null) {
            return false;
        }
        return entries.get("message").toString().matches("(?i).*CSRF token mismatch.*");
    }

    private String resolveFinalDownloadUrl(final String fileToken, final String cfToken) throws Exception {
        final Browser brc = br.cloneBrowser();
        brc.setAllowedResponseCodes(403, 410, 422, 429);
        brc.getHeaders().put("Accept", "application/json");
        brc.getHeaders().put("X-Requested-With", "XMLHttpRequest");
        brc.getHeaders().put("Origin", "https://" + getHost());
        final String referer = br.getURL() != null ? br.getURL() : ("https://" + getHost() + "/");
        brc.getHeaders().put("Referer", referer);
        final String linkApi = "https://" + getHost() + "/download-file/" + fileToken + "/link?cf-turnstile-response=" + Encoding.urlEncode(cfToken);
        brc.getPage(linkApi);
        final String html = brc.getRequest().getHtmlCode();
        if (StringUtils.isNotEmpty(html) && html.startsWith("{")) {
            final Map<String, Object> entries = restoreFromString(html, TypeRef.MAP);
            final Object linkObj = entries.get("link");
            if (linkObj != null && StringUtils.isNotEmpty(linkObj.toString())) {
                return linkObj.toString();
            }
            final Object error = entries.get("error");
            if (error != null) {
                handleDownloadApiError(error.toString());
            }
        }
        final int code = brc.getHttpConnection().getResponseCode();
        if (code == 410) {
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Download ticket rejected (410) — Companion must resolve CDN link on treasure page", 30 * 1000l);
        }
        if (code == 403 || code == 422) {
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, "Turnstile verification failed (" + code + ")", 60 * 1000l);
        }
        /* Fallback: navigate to download-file with Turnstile response (website Download Now button). */
        return "https://" + getHost() + "/download-file/" + fileToken + "?cf-turnstile-response=" + Encoding.urlEncode(cfToken);
    }

    private static boolean looksLikeDirectHttpUrl(final String value) {
        if (StringUtils.isEmpty(value)) {
            return false;
        }
        final String v = value.trim();
        return v.startsWith("https://") || v.startsWith("http://");
    }

    private static boolean isExpiredDownloadPage(final Browser br) {
        if (br == null) {
            return false;
        }
        return br.containsHTML("(?i)Invalid or expired download link|Your download link has expired|Download nicht verfügbar|download link has expired or is invalid");
    }

    private void handleDownloadApiError(final String errorMessage) throws PluginException {
        final String waitSeconds = new Regex(errorMessage, "(?i)wait (\\d+) seconds?").getMatch(0);
        if (waitSeconds != null) {
            throw new PluginException(LinkStatus.ERROR_HOSTER_TEMPORARILY_UNAVAILABLE, "Rate limited", Long.parseLong(waitSeconds) * 1000l);
        } else if (errorMessage.matches("(?i).*expired.*|.*request a new one.*")) {
            /*
             * Usually means Turnstile was solved off the treasure page (e.g. homepage) so /link
             * rejects the ticket. Not a permanent "file missing" — user should retry with Companion.
             */
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, errorMessage, 30 * 1000l);
        } else if (errorMessage.matches("(?i).*verif.*|.*captcha.*|.*turnstile.*|.*try again.*")) {
            /*
             * Do NOT throw ERROR_CAPTCHA here — that immediately re-opens BrowserSolver and creates a
             * tight solve→fail→solve loop when the token itself is rejected server-side.
             */
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, errorMessage, 60 * 1000l);
        } else if (errorMessage.matches("(?i).*limit.*|.*quota.*|.*upgrade.*|.*subscri.*")) {
            throw new PluginException(LinkStatus.ERROR_FATAL, errorMessage);
        } else {
            throw new PluginException(LinkStatus.ERROR_TEMPORARILY_UNAVAILABLE, errorMessage, 5 * 60 * 1000l);
        }
    }

    private boolean attemptStoredDownloadurlDownload(final DownloadLink link) throws Exception {
        final String url = link.getStringProperty(PROPERTY_DIRECTURL);
        if (StringUtils.isEmpty(url)) {
            return false;
        }
        if (StringUtils.containsIgnoreCase(url, "dlproxy.")) {
            /* CDN WAF blocks JD's Java client — always re-solve Turnstile instead of retrying. */
            link.removeProperty(PROPERTY_DIRECTURL);
            return false;
        }
        try {
            final Browser brc = br.cloneBrowser();
            prepareCdnRequestHeaders(brc, link, url);
            dl = new jd.plugins.BrowserAdapter().openDownload(brc, link, url, this.isResumeable(link, null), this.getMaxChunks(link, null));
            if (!this.looksLikeDownloadableContent(dl.getConnection())) {
                brc.followConnection(true);
                throw new IOException("Stored directurl is invalid");
            }
            return true;
        } catch (final BlockedByException e) {
            /*
             * Stale CDN URL from a previous captcha solve. Must NOT wait/retry this URL —
             * that skips Turnstile forever. Drop it and fall through to a fresh captcha.
             */
            logger.log(e);
            try {
                dl.getConnection().disconnect();
            } catch (final Throwable ignore) {
            }
            link.removeProperty(PROPERTY_DIRECTURL);
            link.removeProperty(PROPERTY_CDN_OPENED);
            openCdnInBrowserOnce(link, url);
            return false;
        } catch (final Exception e) {
            logger.log(e);
            try {
                dl.getConnection().disconnect();
            } catch (final Throwable ignore) {
            }
            link.removeProperty(PROPERTY_DIRECTURL);
            return false;
        }
    }

    @Override
    protected void throwFinalConnectionException(Browser br, URLConnectionAdapter con) throws PluginException, IOException {
        throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT);
    }

    @Override
    public boolean hasCaptcha(final DownloadLink link, final Account acc) {
        /* Cloudflare Turnstile via browser companion */
        return true;
    }

    /**
     * After the browser companion closes the AnkerGames tab, raise the JD main window so the
     * user sees the download progress (confirmation that the relay pipe worked).
     */
    private void bringJdToFront() {
        try {
            new EDTRunner() {
                @Override
                protected void runInEDT() {
                    try {
                        final JDGui gui = JDGui.getInstance();
                        if (gui != null) {
                            gui.setFrameState(FrameState.TO_FRONT_FOCUSED);
                        }
                    } catch (final Throwable e) {
                        getLogger().log(e);
                    }
                }
            };
        } catch (final Throwable e) {
            getLogger().log(e);
        }
    }

    @Override
    public int getMaxSimultanFreeDownloadNum() {
        return 1;
    }

    @Override
    public void reset() {
    }

    @Override
    public void resetDownloadlink(DownloadLink link) {
    }
}
