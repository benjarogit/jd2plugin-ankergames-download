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
package jd.plugins.decrypter;

import java.net.URLDecoder;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.appwork.storage.TypeRef;
import org.appwork.utils.StringUtils;
import org.appwork.utils.formatter.SizeFormatter;

import jd.PluginWrapper;
import jd.controlling.AccountController;
import jd.controlling.ProgressController;
import jd.http.Browser;
import jd.http.Cookies;
import jd.nutils.encoding.Encoding;
import jd.parser.Regex;
import jd.plugins.Account;
import jd.plugins.CryptedLink;
import jd.plugins.DecrypterPlugin;
import jd.plugins.DownloadLink;
import jd.plugins.FilePackage;
import jd.plugins.LinkStatus;
import jd.plugins.PluginException;
import jd.plugins.PluginForDecrypt;
import jd.plugins.hoster.AnkergamesNet;

@DecrypterPlugin(revision = "$Revision$", interfaceVersion = 3, names = {}, urls = {})
public class AnkergamesNetCrawler extends PluginForDecrypt {
    /** Fresh CSRF from GET /csrf-token (CDN-cached game pages have a stale meta token). */
    private String freshCsrfToken = null;

    public AnkergamesNetCrawler(PluginWrapper wrapper) {
        super(wrapper);
    }

    @Override
    public Browser createNewBrowserInstance() {
        final Browser br = super.createNewBrowserInstance();
        br.setFollowRedirects(true);
        return br;
    }

    public static List<String[]> getPluginDomains() {
        return AnkergamesNet.getPluginDomains();
    }

    public static String[] getAnnotationNames() {
        return buildAnnotationNames(getPluginDomains());
    }

    @Override
    public String[] siteSupportedNames() {
        return buildSupportedNames(getPluginDomains());
    }

    public static String[] getAnnotationUrls() {
        final List<String> ret = new ArrayList<String>();
        for (final String[] domains : getPluginDomains()) {
            ret.add("https?://(?:www\\.)?" + buildHostsPatternPart(domains) + "/game/([\\w\\-]+)/?");
        }
        return ret.toArray(new String[0]);
    }

    public ArrayList<DownloadLink> decryptIt(final CryptedLink param, ProgressController progress) throws Exception {
        final ArrayList<DownloadLink> ret = new ArrayList<DownloadLink>();
        final String contenturl = param.getCryptedUrl();
        final String slug = new Regex(contenturl, this.getSupportedLinks()).getMatch(0);
        final Account account = AccountController.getInstance().getValidAccount(this.getHost());
        if (account != null) {
            /* Shares this.br via getNewPluginForHostInstance */
            final AnkergamesNet hoster = (AnkergamesNet) this.getNewPluginForHostInstance(this.getHost());
            hoster.login(account, false);
        }
        br.getPage(contenturl);
        if (br.getHttpConnection().getResponseCode() == 404) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND);
        }
        String title = br.getRegex("<h1[^>]*>\\s*([^<]+?)\\s*</h1>").getMatch(0);
        if (title == null) {
            title = br.getRegex("<title>\\s*(.*?)\\s*(?:\\|\\s*AnkerGames)?\\s*</title>").getMatch(0);
        }
        if (title != null) {
            title = Encoding.htmlDecode(title).trim();
            title = title.replaceFirst("(?i)\\s*Free Download.*$", "").trim();
        } else {
            title = slug.replace("-", " ").trim();
        }
        /* Packagizer subfolders reject slash lookalikes (e.g. U+2044) -> INVALID_DESTINATION */
        title = AnkergamesNet.sanitizePathName(title);
        /*
         * Filename must not equal the packagizer subfolder name. Without an extension JD tries to
         * write a file where a folder already exists -> INVALID_DESTINATION.
         */
        final String fileName = AnkergamesNet.buildArchiveFileName(slug, title);
        final String filesize = br.getRegex("(?i)>(\\d+(?:\\.\\d+)?\\s*(?:KB|MB|GB|TB))\\s*<").getMatch(0);
        final String downloadId = br.getRegex("generateDownloadUrl\\((\\d+)\\)").getMatch(0);
        if (downloadId == null) {
            if (br.containsHTML("(?i)Sign In Required|not available in your region|Subscribers Only")) {
                throw new PluginException(LinkStatus.ERROR_PREMIUM, PluginException.VALUE_ID_PREMIUM_ONLY);
            }
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT);
        }
        /*
         * CF-cached guest game pages strip Set-Cookie; HTML csrf-token is stale for this visitor.
         * Site JS calls GET /csrf-token to establish ankergames_session + XSRF-TOKEN and refresh the token.
         */
        ensureLaravelSession(br);
        Map<String, Object> entries = requestGenerateDownloadUrl(br, downloadId);
        if (isCsrfMismatch(entries)) {
            logger.info("CSRF mismatch on generate-download-url -> refresh session and retry once");
            ensureLaravelSession(br);
            entries = requestGenerateDownloadUrl(br, downloadId);
        }
        if (Boolean.TRUE.equals(entries.get("geo_blocked")) || "subscribe".equals(entries.get("modal_type"))) {
            throw new PluginException(LinkStatus.ERROR_FATAL, "Download blocked for this region/account");
        } else if (Boolean.TRUE.equals(entries.get("show_upgrade"))) {
            final Object details = entries.get("details");
            final String msg = details != null ? details.toString() : "Download limit reached";
            throw new PluginException(LinkStatus.ERROR_PREMIUM, msg, PluginException.VALUE_ID_PREMIUM_ONLY);
        }
        final Object error = entries.get("error");
        if (error != null) {
            final String errorMessage = error.toString();
            final String waitSeconds = new Regex(errorMessage, "(?i)wait (\\d+) seconds?").getMatch(0);
            if (waitSeconds != null) {
                throw new PluginException(LinkStatus.ERROR_HOSTER_TEMPORARILY_UNAVAILABLE, "Rate limited", Long.parseLong(waitSeconds) * 1000l);
            }
            throw new PluginException(LinkStatus.ERROR_FATAL, errorMessage);
        }
        if (isCsrfMismatch(entries)) {
            throw new PluginException(LinkStatus.ERROR_HOSTER_TEMPORARILY_UNAVAILABLE, "CSRF token mismatch", 60 * 1000l);
        }
        if (!Boolean.TRUE.equals(entries.get("success"))) {
            final Object message = entries.get("message");
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, message != null ? message.toString() : null);
        }
        final String downloadUrl = (String) entries.get("download_url");
        if (StringUtils.isEmpty(downloadUrl)) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT);
        }
        final DownloadLink link = this.createDownloadlink(downloadUrl);
        link.setFinalFileName(fileName);
        link.setName(fileName);
        /* So the hoster can mint a fresh treasure-box URL right before Turnstile (tickets expire fast). */
        link.setProperty(AnkergamesNet.PROPERTY_GAME_URL, contenturl);
        link.setProperty(AnkergamesNet.PROPERTY_DOWNLOAD_ID, downloadId);
        if (filesize != null) {
            link.setDownloadSize(SizeFormatter.getSize(filesize));
        }
        link.setAvailable(true);
        final FilePackage fp = FilePackage.getInstance();
        fp.setName(title);
        fp.setPackageKey(this.getHost() + "://game/" + slug);
        link._setFilePackage(fp);
        ret.add(link);
        return ret;
    }

    /**
     * Establish Laravel session cookies on CF-cached guest pages (same as site fetch('/csrf-token')).
     * Cookies are stored on {@code br}; optional JSON token is kept via a synthetic meta-compatible header source.
     */
    private void ensureLaravelSession(final Browser br) throws Exception {
        final Browser brc = br.cloneBrowser();
        brc.getHeaders().put("Accept", "application/json");
        brc.getHeaders().put("X-Requested-With", "XMLHttpRequest");
        brc.getHeaders().put("Referer", br.getURL() != null ? br.getURL() : ("https://" + this.getHost() + "/"));
        brc.getPage("/csrf-token");
        /* Merge cookies from csrf-token response into primary browser */
        br.setCookies(brc.getCookies(br.getHost()));
        final String html = brc.getRequest().getHtmlCode();
        if (StringUtils.isNotEmpty(html) && html.startsWith("{")) {
            final Map<String, Object> csrfJson = restoreFromString(html, TypeRef.MAP);
            final Object token = csrfJson.get("token");
            if (token != null) {
                this.freshCsrfToken = token.toString();
            }
        } else if (brc.containsHTML("(?i)Just a moment|cf-mitigated|challenge-platform")) {
            throw new PluginException(LinkStatus.ERROR_HOSTER_TEMPORARILY_UNAVAILABLE, "Cloudflare challenge on /csrf-token", 2 * 60 * 1000l);
        }
        final String session = br.getCookie(br.getHost(), "ankergames_session", Cookies.NOTDELETEDPATTERN);
        final String xsrf = br.getCookie(br.getHost(), "XSRF-TOKEN", Cookies.NOTDELETEDPATTERN);
        if (session == null && xsrf == null) {
            logger.warning("GET /csrf-token did not set session cookies");
        }
    }

    /**
     * POST /generate-download-url/{id} with Laravel CSRF headers matching the website JS.
     */
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
        /* Keep any refreshed cookies (e.g. rotated XSRF) */
        br.setCookies(brc.getCookies(br.getHost()));
        final int code = brc.getHttpConnection().getResponseCode();
        if (code == 404) {
            throw new PluginException(LinkStatus.ERROR_FILE_NOT_FOUND);
        }
        final String html = brc.getRequest().getHtmlCode();
        if (StringUtils.isEmpty(html) || !html.startsWith("{")) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Unexpected generate-download-url response (" + code + ")");
        }
        return restoreFromString(html, TypeRef.MAP);
    }

    /**
     * Prefer XSRF-TOKEN cookie / /csrf-token JSON over CDN-stale meta csrf-token.
     */
    private void applyLaravelCsrfHeaders(final Browser source, final Browser target) throws Exception {
        String xsrfCookie = source.getCookie(source.getHost(), "XSRF-TOKEN", Cookies.NOTDELETEDPATTERN);
        if (xsrfCookie == null) {
            xsrfCookie = source.getCookie(source.getHost(), "XSRF-TOKEN");
        }
        if (xsrfCookie != null) {
            /* Cookie value is URL-encoded; Laravel expects decoded value in X-XSRF-TOKEN */
            String decoded = xsrfCookie;
            try {
                decoded = URLDecoder.decode(xsrfCookie, "UTF-8");
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
        if (metaCsrf == null) {
            metaCsrf = source.getRegex("csrf-token\"\\s*content=\"([^\"]+)\"").getMatch(0);
        }
        if (metaCsrf != null) {
            target.getHeaders().put("X-CSRF-TOKEN", metaCsrf);
            return;
        }
        throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Missing CSRF token");
    }

    private boolean isCsrfMismatch(final Map<String, Object> entries) {
        if (entries == null) {
            return false;
        }
        final Object message = entries.get("message");
        if (message == null) {
            return false;
        }
        return message.toString().matches("(?i).*CSRF token mismatch.*");
    }
}
