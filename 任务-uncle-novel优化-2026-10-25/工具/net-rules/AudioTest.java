import com.unclezs.novel.analyzer.core.helper.RuleHelper;
import com.unclezs.novel.analyzer.core.model.AnalyzerRule;
import com.unclezs.novel.analyzer.core.NovelMatcher;
import com.unclezs.novel.analyzer.model.Chapter;
import com.unclezs.novel.analyzer.model.Novel;
import com.unclezs.novel.analyzer.request.Http;
import com.unclezs.novel.analyzer.request.HttpConfig;
import com.unclezs.novel.analyzer.request.okhttp.OkHttpClient;
import com.unclezs.novel.analyzer.request.spi.HttpProvider;
import com.unclezs.novel.analyzer.spider.NovelSpider;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 有声书源端到端实测（应用同款 novel-analyzer.jar）。
 *
 * <p>模拟 app 的有声流程：搜索 → 目录 → content(chapterUrl) 取音频地址 → HTTP 校验音频可播。
 * 与 app 的 SearchAudioView.withAudioUrl / AudioBookShelfView.loadChapter 一致：
 * 音频 URL 通过 NovelSpider.content(章节页 url) 得到，校验时带 Referer=章节页。
 *
 * <p>用法：java AudioTest &lt;rules.json&gt; &lt;keyword&gt; &lt;out.json&gt; [siteRegex]
 */
public class AudioTest {

  private static final String UA_DEFAULT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";

  public static void main(String[] args) throws Exception {
    if (args.length < 3) {
      System.out.println("usage: AudioTest <rules.json> <keyword> <out.json> [siteRegex]");
      System.exit(2);
    }
    String json = new String(Files.readAllBytes(Paths.get(args[0])), StandardCharsets.UTF_8);
    RuleHelper.loadRules(json);
    String keyword = args[1];
    Pattern siteFilter = args.length > 3 && !args[3].isEmpty() ? Pattern.compile(args[3]) : null;

    HttpProvider provider = Http.getStaticHttpClient();
    if (provider instanceof OkHttpClient) {
      HttpConfig config = HttpConfig.defaultConfig();
      config.setConnectionTimeout(10);
      config.setReadTimeout(20);
      config.setFollowRedirect(true);
      config.setRetryOnFailed(false);
      ((OkHttpClient) provider).configuration(config);
    }

    List<String> lines = new ArrayList<>();
    for (AnalyzerRule rule : RuleHelper.rules()) {
      String site = rule.getSite() == null ? "" : rule.getSite();
      if (siteFilter != null && !siteFilter.matcher(site).find()) {
        continue;
      }
      if (!Boolean.TRUE.equals(rule.getAudio())) {
        continue;
      }
      long t0 = System.currentTimeMillis();
      int searchCount = 0;
      int tocCount = 0;
      String novelUrl = "";
      String chapterUrl = "";
      String audioUrl = "";
      String audioStatus = "";
      String audioType = "";
      long audioBytes = 0;
      String head = "";
      String err = "";
      try {
        List<Novel> novels = NovelMatcher.search(1, keyword, rule, n -> {
        });
        searchCount = novels == null ? 0 : novels.size();
        if (searchCount > 0) {
          Novel novel = novels.get(0);
          novelUrl = novel.getUrl();
          NovelSpider spider = new NovelSpider(rule);
          List<Chapter> toc = spider.toc(novelUrl);
          tocCount = toc == null ? 0 : toc.size();
          if (tocCount > 0) {
            Chapter chapter = toc.get(Math.min(1, toc.size() - 1));
            chapterUrl = chapter.getUrl();
            audioUrl = spider.content(chapterUrl);
            if (audioUrl != null && !audioUrl.isEmpty()) {
              Object[] probe = probeAudio(audioUrl, chapterUrl, rule);
              audioStatus = String.valueOf(probe[0]);
              audioType = String.valueOf(probe[1]);
              audioBytes = (Long) probe[2];
              head = String.valueOf(probe[3]);
            }
          }
        }
      } catch (Throwable e) {
        Throwable c = e;
        StringBuilder sb = new StringBuilder();
        int i = 0;
        while (c != null && i++ < 5 && sb.length() < 300) {
          if (sb.length() > 0) {
            sb.append(" <- ");
          }
          sb.append(c.getClass().getSimpleName()).append(": ").append(String.valueOf(c.getMessage()));
          c = c.getCause();
        }
        err = sb.toString();
      }
      long ms = System.currentTimeMillis() - t0;
      String line = "{"
        + "\"name\":" + q(rule.getName())
        + ",\"site\":" + q(site)
        + ",\"group\":" + q(rule.getGroup())
        + ",\"search\":" + searchCount
        + ",\"toc\":" + tocCount
        + ",\"novelUrl\":" + q(novelUrl)
        + ",\"chapterUrl\":" + q(chapterUrl)
        + ",\"audioUrl\":" + q(audioUrl)
        + ",\"audioStatus\":" + q(audioStatus)
        + ",\"audioType\":" + q(audioType)
        + ",\"audioBytes\":" + audioBytes
        + ",\"audioHead\":" + q(head)
        + ",\"ms\":" + ms
        + ",\"error\":" + q(err) + "}";
      lines.add(line);
      System.out.println("[AUDIO] name=" + rule.getName() + " site=" + site
        + " search=" + searchCount + " toc=" + tocCount
        + " audio=" + (audioStatus.isEmpty() ? "-" : audioStatus) + " type=" + audioType
        + " bytes=" + audioBytes + (err.isEmpty() ? "" : " err=" + err));
      if (!audioUrl.isEmpty()) {
        System.out.println("        audioUrl=" + audioUrl);
      }
    }
    Files.write(Paths.get(args[2]), ("[\n" + String.join(",\n", lines) + "\n]\n").getBytes(StandardCharsets.UTF_8));
    System.out.println("== SUMMARY tested=" + lines.size() + " -> " + Paths.get(args[2]).toAbsolutePath());
  }

  /** 校验音频 URL：跟随 302，取状态、Content-Type、长度、首 4 字节（判断是否 MP3 等）。 */
  private static Object[] probeAudio(String audioUrl, String referer, AnalyzerRule rule) {
    String ua = (rule.getParams() != null && rule.getParams().getUserAgent() != null)
      ? rule.getParams().getUserAgent() : UA_DEFAULT;
    HttpURLConnection conn = null;
    try {
      conn = (HttpURLConnection) new URL(audioUrl).openConnection();
      conn.setRequestMethod("GET");
      conn.setConnectTimeout(12000);
      conn.setReadTimeout(20000);
      conn.setInstanceFollowRedirects(true);
      conn.setRequestProperty("User-Agent", ua);
      conn.setRequestProperty("Referer", referer == null ? "" : referer);
      conn.setRequestProperty("Accept", "*/*");
      int status = conn.getResponseCode();
      String type = conn.getContentType();
      long len = conn.getContentLengthLong();
      byte[] buf = new byte[4096];
      int read = 0;
      InputStream in = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
      if (in != null) {
        read = in.read(buf);
        in.close();
      }
      StringBuilder hex = new StringBuilder();
      for (int i = 0; i < Math.min(4, Math.max(0, read)); i++) {
        hex.append(String.format("%02x", buf[i]));
      }
      return new Object[]{status, type, Math.max(len, read), hex.toString()};
    } catch (Exception e) {
      return new Object[]{"ERR", e.getClass().getSimpleName() + ": " + e.getMessage(), 0L, ""};
    } finally {
      if (conn != null) {
        conn.disconnect();
      }
    }
  }

  private static String q(String s) {
    if (s == null) {
      return "null";
    }
    StringBuilder b = new StringBuilder("\"");
    for (int i = 0; i < s.length(); i++) {
      char c = s.charAt(i);
      switch (c) {
        case '"':
          b.append("\\\"");
          break;
        case '\\':
          b.append("\\\\");
          break;
        case '\n':
          b.append("\\n");
          break;
        case '\r':
          b.append("\\r");
          break;
        case '\t':
          b.append("\\t");
          break;
        default:
          if (c < 0x20) {
            b.append(String.format("\\u%04x", (int) c));
          } else {
            b.append(c);
          }
      }
    }
    return b.append('"').toString();
  }
}
