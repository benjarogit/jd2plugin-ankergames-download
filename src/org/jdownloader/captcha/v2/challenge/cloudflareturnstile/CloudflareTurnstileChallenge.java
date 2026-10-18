package org.jdownloader.captcha.v2.challenge.cloudflareturnstile;

import java.awt.Rectangle;
import java.io.IOException;
import java.net.URL;

import jd.http.Browser;
import jd.plugins.LinkStatus;
import jd.plugins.Plugin;
import jd.plugins.PluginException;

import org.appwork.exceptions.WTFException;
import org.appwork.net.protocol.http.HTTPConstants;
import org.appwork.net.protocol.http.HTTPConstants.ResponseCode;
import org.appwork.remoteapi.exceptions.RemoteAPIException;
import org.appwork.utils.IO;
import org.appwork.utils.StringUtils;
import org.appwork.utils.net.HTTPHeader;
import org.appwork.utils.net.httpserver.requests.GetRequest;
import org.appwork.utils.net.httpserver.requests.HttpRequest;
import org.appwork.utils.net.httpserver.responses.HttpResponse;
import org.jdownloader.captcha.v2.AbstractResponse;
import org.jdownloader.captcha.v2.solver.browser.AbstractBrowserChallenge;
import org.jdownloader.captcha.v2.solver.browser.BrowserReference;
import org.jdownloader.captcha.v2.solver.browser.BrowserViewport;
import org.jdownloader.captcha.v2.solver.browser.BrowserWindow;
import org.jdownloader.gui.translate._GUI;

public abstract class CloudflareTurnstileChallenge extends AbstractBrowserChallenge {
    private final String siteKey;

    public String getSiteKey() {
        return siteKey;
    }

    public CloudflareTurnstileChallenge(final Plugin plugin, final String siteKey) throws PluginException {
        super("cloudflareturnstile", plugin);
        this.siteKey = siteKey;
        if (!AbstractCloudflareTurnstileCaptcha.isValidSiteKey(siteKey)) {
            throw new PluginException(LinkStatus.ERROR_PLUGIN_DEFECT, "Bad SiteKey:" + siteKey);
        }
    }

    public static String getChallengeType() {
        return CloudflareTurnstileChallenge.class.getSimpleName();
    }

    public String getSiteDomain() {
        try {
            final String siteUrl = getSiteUrl();
            if (StringUtils.isNotEmpty(siteUrl)) {
                return Browser.getHost(siteUrl, true);
            }
        } catch (final Throwable ignore) {
        }
        if (plugin != null) {
            return plugin.getHost();
        }
        return null;
    }

    /**
     * Optional hoster-specific token (e.g. AnkerGames /download-file/TOKEN) for the companion
     * extension to resolve the final CDN URL after Turnstile — without relying on short-lived
     * signed /download/... pages that expire while the captcha dialog is open.
     */
    public String getFileToken() {
        return null;
    }

    /** Optional: stable game page so the companion can mint a fresh /download/ ticket in-browser. */
    public String getGameUrl() {
        return null;
    }

    public String getDownloadId() {
        return null;
    }

    /**
     * Optional localhost relay base (e.g. http://127.0.0.1:PORT) so the companion can push CDN
     * bytes into JDownloader while AnkerGames only sees a browser fetch.
     */
    public String getRelayUrl() {
        return null;
    }

    @Override
    public String getHTML(HttpRequest request, String id) {
        try {
            final URL url = CloudflareTurnstileChallenge.class.getResource("turnstile.html");
            String html = IO.readURLToString(url);
            html = html.replace("%%%challengeType%%%", getChallengeType());
            html = html.replace("%%%headTitle%%%", _GUI.T.recaptchav2_head_title());
            html = html.replace("%%%headDescription%%%", _GUI.T.recaptchav2_head_description());
            html = html.replace("%%%captchaHeader%%%", "Cloudflare Turnstile");
            html = html.replace("%%%siteUrl%%%", StringUtils.valueOrEmpty(getSiteUrl()));
            html = html.replace("%%%fileToken%%%", StringUtils.valueOrEmpty(getFileToken()));
            html = html.replace("%%%gameUrl%%%", StringUtils.valueOrEmpty(getGameUrl()));
            html = html.replace("%%%downloadId%%%", StringUtils.valueOrEmpty(getDownloadId()));
            html = html.replace("%%%relayUrl%%%", StringUtils.valueOrEmpty(getRelayUrl()));
            html = html.replace("%%%siteDomain%%%", StringUtils.valueOrEmpty(getSiteDomain()));
            html = html.replace("%%%sitekey%%%", getSiteKey());
            html = html.replace("%%%challengeId%%%", Long.toString(getId().getID()));
            html = html.replace("%%%boundToDomain%%%", String.valueOf(true));
            html = html.replace("%%%sameOrigin%%%", String.valueOf(true));
            html = html.replace("%%%favIcon%%%", "");
            html = html.replace("%%%unsupportedBrowser%%%", "none");
            return html;
        } catch (IOException e) {
            throw new WTFException(e);
        }
    }

    @Override
    public BrowserViewport getBrowserViewport(BrowserWindow screenResource, Rectangle elementBounds) {
        return null;
    }

    /**
     * Same contract as {@link org.jdownloader.captcha.v2.challenge.hcaptcha.HCaptchaChallenge}: Companion /
     * BrowserSolver posts {@code do=solve&response=TOKEN}; without this hook the token is ignored.
     */
    @Override
    public boolean onGetRequest(final BrowserReference brRef, final GetRequest request, final HttpResponse response) throws IOException, RemoteAPIException {
        synchronized (this) {
            final String pDo = request.getParameterbyKey("do");
            if ("solve".equals(pDo)) {
                final String responsetoken = request.getParameterbyKey("response");
                brRef.onResponse(responsetoken);
                response.setResponseCode(ResponseCode.SUCCESS_OK);
                response.getResponseHeaders().add(new HTTPHeader(HTTPConstants.HEADER_RESPONSE_CONTENT_TYPE, "text/html; charset=utf-8"));
                response.getOutputStream(true).write("Please Close the Browser now".getBytes("UTF-8"));
                return true;
            }
            return false;
        }
    }

    public boolean isCaptchaResponseValid() {
        if (super.isCaptchaResponseValid() && AbstractCloudflareTurnstileCaptcha.looksLikeValidToken(getResult().getValue())) {
            return true;
        } else {
            return false;
        }
    }

    @Override
    protected String getCaptchaNameSpace() {
        return "turn";
    }

    @Override
    public boolean validateResponse(AbstractResponse<String> response) {
        return super.validateResponse(response) && AbstractCloudflareTurnstileCaptcha.looksLikeValidToken(response.getValue());
    }
}
