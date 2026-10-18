package jd.plugins.components;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import org.appwork.utils.logging2.LogInterface;

import com.sun.net.httpserver.Headers;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

/**
 * Localhost bridge: Companion fetches the CDN URL with a real browser TLS stack and POSTs the
 * bytes here; JDownloader GETs {@link #getFileUrl()} so the transfer is managed by JD while
 * AnkerGames/Cloudflare only see the browser.
 * <p>
 * Uses a BlockingQueue (not Piped streams) and a cached thread-pool executor so GET /file can
 * wait while POST /push runs concurrently — a single-thread executor would deadlock.
 */
public class AnkergamesCdnRelay implements AutoCloseable {
    private static final byte[]              EOF          = new byte[0];
    private static final int                 QUEUE_CAP    = 64;
    private static final long                WAIT_PUSH_MS = 5 * 60 * 1000L;

    private final HttpServer                 server;
    private final ExecutorService            executor;
    private final LogInterface               logger;
    private final LinkedBlockingQueue<byte[]> queue       = new LinkedBlockingQueue<byte[]>(QUEUE_CAP);
    private final AtomicBoolean              pushStarted  = new AtomicBoolean(false);
    private final AtomicBoolean              pushEnded    = new AtomicBoolean(false);
    private final AtomicBoolean              closed       = new AtomicBoolean(false);
    private final AtomicLong                 contentLength = new AtomicLong(-1);
    private final AtomicReference<String>    contentType  = new AtomicReference<String>("application/octet-stream");
    private final AtomicReference<Throwable> pushError    = new AtomicReference<Throwable>();
    private final Object                     startLock    = new Object();

    private AnkergamesCdnRelay(final HttpServer server, final ExecutorService executor, final LogInterface logger) {
        this.server = server;
        this.executor = executor;
        this.logger = logger;
    }

    public static AnkergamesCdnRelay start(final LogInterface logger) throws IOException {
        final ExecutorService executor = Executors.newCachedThreadPool();
        final HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        final AnkergamesCdnRelay relay = new AnkergamesCdnRelay(server, executor, logger);
        server.createContext("/file", new com.sun.net.httpserver.HttpHandler() {
            @Override
            public void handle(final HttpExchange exchange) throws IOException {
                relay.handleFile(exchange);
            }
        });
        server.createContext("/push", new com.sun.net.httpserver.HttpHandler() {
            @Override
            public void handle(final HttpExchange exchange) throws IOException {
                relay.handlePush(exchange);
            }
        });
        server.createContext("/status", new com.sun.net.httpserver.HttpHandler() {
            @Override
            public void handle(final HttpExchange exchange) throws IOException {
                relay.handleStatus(exchange);
            }
        });
        server.setExecutor(executor);
        server.start();
        if (logger != null) {
            logger.info("AnkergamesCdnRelay listening on " + relay.getBaseUrl());
        }
        return relay;
    }

    public String getBaseUrl() {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    /** URL JDownloader should openDownload(). */
    public String getFileUrl() {
        return getBaseUrl() + "/file";
    }

    /** URL Companion POSTs the CDN body to. */
    public String getPushUrl() {
        return getBaseUrl() + "/push";
    }

    private void markPushStarted() {
        if (pushStarted.compareAndSet(false, true)) {
            synchronized (startLock) {
                startLock.notifyAll();
            }
            if (logger != null) {
                logger.info("AnkergamesCdnRelay push started, contentLength=" + contentLength.get());
            }
        }
    }

    private boolean awaitPushStarted(final long timeoutMs) throws InterruptedException {
        final long deadline = System.currentTimeMillis() + timeoutMs;
        synchronized (startLock) {
            while (!pushStarted.get() && !closed.get()) {
                final long left = deadline - System.currentTimeMillis();
                if (left <= 0) {
                    return false;
                }
                startLock.wait(left);
            }
        }
        return pushStarted.get();
    }

    private void handleStatus(final HttpExchange ex) throws IOException {
        if (!"GET".equalsIgnoreCase(ex.getRequestMethod())) {
            ex.sendResponseHeaders(405, -1);
            ex.close();
            return;
        }
        final byte[] body = ("{\"pushStarted\":" + pushStarted.get() + ",\"pushEnded\":" + pushEnded.get() + ",\"closed\":" + closed.get() + ",\"queue\":" + queue.size() + "}").getBytes("UTF-8");
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        ex.sendResponseHeaders(200, body.length);
        ex.getResponseBody().write(body);
        ex.close();
    }

    private void handleFile(final HttpExchange ex) throws IOException {
        if ("OPTIONS".equalsIgnoreCase(ex.getRequestMethod())) {
            cors(ex);
            ex.sendResponseHeaders(204, -1);
            ex.close();
            return;
        }
        if (!"GET".equalsIgnoreCase(ex.getRequestMethod()) && !"HEAD".equalsIgnoreCase(ex.getRequestMethod())) {
            ex.sendResponseHeaders(405, -1);
            ex.close();
            return;
        }
        if (logger != null) {
            logger.info("AnkergamesCdnRelay GET /file from " + ex.getRemoteAddress());
        }
        try {
            if (!awaitPushStarted(WAIT_PUSH_MS)) {
                final byte[] err = "Relay timeout: companion did not start CDN push".getBytes("UTF-8");
                ex.sendResponseHeaders(504, err.length);
                ex.getResponseBody().write(err);
                ex.close();
                return;
            }
            final Throwable err = pushError.get();
            if (err != null) {
                final byte[] msg = ("Relay push failed: " + err.getMessage()).getBytes("UTF-8");
                ex.sendResponseHeaders(502, msg.length);
                ex.getResponseBody().write(msg);
                ex.close();
                return;
            }
            final Headers rh = ex.getResponseHeaders();
            rh.add("Content-Type", contentType.get());
            rh.add("Accept-Ranges", "none");
            rh.add("Cache-Control", "no-store");
            final long len = contentLength.get();
            if (len >= 0) {
                rh.add("Content-Length", String.valueOf(len));
                ex.sendResponseHeaders(200, len);
            } else {
                /* -1 = unknown length / chunked */
                ex.sendResponseHeaders(200, 0);
            }
            if ("HEAD".equalsIgnoreCase(ex.getRequestMethod())) {
                ex.close();
                return;
            }
            final OutputStream os = ex.getResponseBody();
            long written = 0;
            while (true) {
                final byte[] chunk = queue.poll(30, TimeUnit.SECONDS);
                if (chunk == null) {
                    if (closed.get() || pushError.get() != null) {
                        break;
                    }
                    /* companion still fetching — keep waiting */
                    continue;
                }
                if (chunk == EOF || (chunk.length == 0 && pushEnded.get())) {
                    break;
                }
                if (chunk.length == 0) {
                    continue;
                }
                os.write(chunk);
                written += chunk.length;
            }
            os.flush();
            if (logger != null) {
                logger.info("AnkergamesCdnRelay GET /file finished, bytes=" + written);
            }
        } catch (final InterruptedException e) {
            Thread.currentThread().interrupt();
            try {
                ex.sendResponseHeaders(503, -1);
            } catch (final IOException ignore) {
            }
        } catch (final IOException e) {
            if (logger != null) {
                logger.log(e);
            }
        } finally {
            try {
                ex.close();
            } catch (final Exception ignore) {
            }
        }
    }

    private void handlePush(final HttpExchange ex) throws IOException {
        if ("OPTIONS".equalsIgnoreCase(ex.getRequestMethod())) {
            cors(ex);
            ex.sendResponseHeaders(204, -1);
            ex.close();
            return;
        }
        if (!"POST".equalsIgnoreCase(ex.getRequestMethod()) && !"PUT".equalsIgnoreCase(ex.getRequestMethod())) {
            ex.sendResponseHeaders(405, -1);
            ex.close();
            return;
        }
        final String phase = queryParam(ex.getRequestURI().getRawQuery(), "phase");
        try {
            final Headers req = ex.getRequestHeaders();
            applyMetaHeaders(req, phase);
            if ("start".equalsIgnoreCase(phase)) {
                exhaust(ex.getRequestBody());
                markPushStarted();
                okJson(ex);
                return;
            }
            if ("end".equalsIgnoreCase(phase)) {
                exhaust(ex.getRequestBody());
                pushEnded.set(true);
                queue.offer(EOF);
                markPushStarted();
                okJson(ex);
                if (logger != null) {
                    logger.info("AnkergamesCdnRelay push ended");
                }
                return;
            }
            /* full-body push (no phase) or phase=chunk */
            if (phase == null || phase.length() == 0) {
                markPushStarted();
            }
            final InputStream in = ex.getRequestBody();
            final byte[] buf = new byte[256 * 1024];
            int n;
            while ((n = in.read(buf)) >= 0) {
                if (n == 0) {
                    continue;
                }
                final byte[] copy = new byte[n];
                System.arraycopy(buf, 0, copy, 0, n);
                queue.put(copy);
            }
            if (phase == null || phase.length() == 0) {
                pushEnded.set(true);
                queue.offer(EOF);
            }
            okJson(ex);
        } catch (final Throwable e) {
            pushError.set(e);
            markPushStarted();
            pushEnded.set(true);
            queue.offer(EOF);
            if (logger != null) {
                logger.log(e);
            }
            try {
                final byte[] msg = ("{\"ok\":false,\"error\":\"" + e.getClass().getSimpleName() + "\"}").getBytes("UTF-8");
                cors(ex);
                ex.sendResponseHeaders(500, msg.length);
                ex.getResponseBody().write(msg);
            } catch (final Exception ignore) {
            }
        } finally {
            try {
                ex.close();
            } catch (final Exception ignore) {
            }
        }
    }

    private void applyMetaHeaders(final Headers req, final String phase) {
        if (phase != null && !"start".equalsIgnoreCase(phase) && phase.length() > 0 && !"chunk".equalsIgnoreCase(phase)) {
            return;
        }
        final String ct = first(req, "X-Orig-Content-Type");
        if (ct != null && ct.length() > 0) {
            contentType.set(ct);
        } else {
            final String ct2 = first(req, "Content-Type");
            if (ct2 != null && !ct2.contains("json") && !ct2.contains("octet-stream") && ct2.length() > 0) {
                contentType.set(ct2);
            }
        }
        final String origLen = first(req, "X-Orig-Content-Length");
        if (origLen != null && origLen.length() > 0) {
            try {
                contentLength.set(Long.parseLong(origLen.trim()));
            } catch (final NumberFormatException ignore) {
            }
        } else if (phase == null || phase.length() == 0) {
            final String cl = first(req, "Content-Length");
            if (cl != null) {
                try {
                    contentLength.set(Long.parseLong(cl.trim()));
                } catch (final NumberFormatException ignore) {
                }
            }
        }
    }

    private void okJson(final HttpExchange ex) throws IOException {
        cors(ex);
        final byte[] ok = "{\"ok\":true}".getBytes("UTF-8");
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.sendResponseHeaders(200, ok.length);
        ex.getResponseBody().write(ok);
    }

    private static void exhaust(final InputStream in) throws IOException {
        final byte[] buf = new byte[4096];
        while (in.read(buf) >= 0) {
            /* discard */
        }
    }

    private static String queryParam(final String rawQuery, final String key) {
        if (rawQuery == null || rawQuery.length() == 0) {
            return null;
        }
        for (final String part : rawQuery.split("&")) {
            final int eq = part.indexOf('=');
            final String k = eq >= 0 ? part.substring(0, eq) : part;
            if (key.equals(k)) {
                return eq >= 0 ? part.substring(eq + 1) : "";
            }
        }
        return null;
    }

    private static void cors(final HttpExchange ex) {
        final Headers h = ex.getResponseHeaders();
        h.set("Access-Control-Allow-Origin", "*");
        h.set("Access-Control-Allow-Methods", "GET,HEAD,POST,PUT,OPTIONS");
        h.set("Access-Control-Allow-Headers", "Content-Type,X-Orig-Content-Length,X-Orig-Content-Type");
    }

    private static String first(final Headers h, final String name) {
        return h.getFirst(name);
    }

    @Override
    public void close() {
        if (!closed.compareAndSet(false, true)) {
            return;
        }
        pushEnded.set(true);
        markPushStarted();
        queue.offer(EOF);
        try {
            server.stop(0);
        } catch (final Exception ignore) {
        }
        try {
            executor.shutdownNow();
        } catch (final Exception ignore) {
        }
    }
}
