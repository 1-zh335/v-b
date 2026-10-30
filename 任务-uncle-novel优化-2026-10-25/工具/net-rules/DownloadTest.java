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

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 用应用自带的 novel-analyzer.jar 实测「搜索 → 详情 → 目录 → 正文」完整下载链。
 *
 * <p>只测第一条命中的规则（按 site 正则）。每一步失败都会打印异常链，便于判断
 * 书源是「只能搜书」还是「能搜 + 能解析目录 + 能下正文」。
 *
 * <p>用法：java DownloadTest &lt;rules.json&gt; &lt;siteRegex&gt; &lt;keyword&gt;
 */
public class DownloadTest {

  public static void main(String[] args) throws Exception {
    if (args.length < 3) {
      System.out.println("usage: DownloadTest <rules.json> <siteRegex> <keyword>");
      System.exit(2);
    }
    String json = new String(Files.readAllBytes(Paths.get(args[0])), StandardCharsets.UTF_8);
    RuleHelper.loadRules(json);
    Pattern filter = Pattern.compile(args[1]);
    String keyword = args[2];
    AnalyzerRule target = null;
    for (AnalyzerRule r : RuleHelper.rules()) {
      if (r.getSite() != null && filter.matcher(r.getSite()).find() && !Boolean.TRUE.equals(r.getAudio())) {
        target = r;
        break;
      }
    }
    if (target == null) {
      System.out.println("== no rule matched site regex: " + args[1]);
      System.exit(3);
    }
    System.out.println("== rule: " + target.getName() + " site=" + target.getSite());

    HttpProvider provider = Http.getStaticHttpClient();
    if (provider instanceof OkHttpClient) {
      HttpConfig config = HttpConfig.defaultConfig();
      config.setConnectionTimeout(12);
      config.setReadTimeout(40);
      config.setFollowRedirect(true);
      config.setRetryOnFailed(false);
      ((OkHttpClient) provider).configuration(config);
    }

    // 1. 搜索
    long t0 = System.currentTimeMillis();
    List<Novel> novels = NovelMatcher.search(1, keyword, target, n -> {
    });
    System.out.println("[1] search count=" + novels.size() + " ms=" + (System.currentTimeMillis() - t0));
    if (novels.isEmpty()) {
      System.out.println("RESULT search=EMPTY");
      return;
    }
    Novel first = novels.get(0);
    System.out.println("    first: title=" + first.getTitle() + " author=" + first.getAuthor() + " url=" + first.getUrl());
    NovelSpider spider = new NovelSpider(target);

    // 2. 详情（可选，失败不算致命）
    try {
      t0 = System.currentTimeMillis();
      Novel detail = spider.details(first.getUrl());
      System.out.println("[2] details ms=" + (System.currentTimeMillis() - t0) + " title=" + detail.getTitle()
        + " author=" + detail.getAuthor() + " category=" + detail.getCategory() + " state=" + detail.getState()
        + " wordCount=" + detail.getWordCount() + " cover=" + detail.getCoverUrl());
    } catch (Throwable e) {
      System.out.println("[2] details FAILED: " + chain(e));
    }

    // 3. 目录
    List<Chapter> chapters = null;
    try {
      t0 = System.currentTimeMillis();
      chapters = spider.toc(first.getUrl());
      System.out.println("[3] toc count=" + chapters.size() + " ms=" + (System.currentTimeMillis() - t0));
      if (!chapters.isEmpty()) {
        Chapter c0 = chapters.get(0);
        Chapter cl = chapters.get(chapters.size() - 1);
        System.out.println("    first chapter: " + c0.getName() + " -> " + c0.getUrl());
        System.out.println("    last  chapter: " + cl.getName() + " -> " + cl.getUrl());
      }
    } catch (Throwable e) {
      System.out.println("[3] toc FAILED: " + chain(e));
    }
    if (chapters == null || chapters.isEmpty()) {
      System.out.println("RESULT search=OK toc=FAIL content=SKIP");
      return;
    }

    // 4. 正文
    try {
      t0 = System.currentTimeMillis();
      String content = chapters.size() > 1 ? spider.content(chapters.get(1).getUrl()) : spider.content(chapters.get(0).getUrl());
      int len = content == null ? 0 : content.length();
      System.out.println("[4] content length=" + len + " ms=" + (System.currentTimeMillis() - t0));
      if (len > 0) {
        int puaLeft = 0;
        for (int ci = 0; ci < content.length(); ci++) {
          char cc = content.charAt(ci);
          if (cc >= 0xE3E8 && cc <= 0xE55B) {
            puaLeft++;
          }
        }
        System.out.println("    puaLeft(0xE3E8-0xE55B)=" + puaLeft);
        int literalBreak = countOccurrences(content, "\\r\\n");
        int realCrlf = countOccurrences(content, "\r\n");
        int realLf = countOccurrences(content, "\n");
        System.out.println("    linebreak: literal(\\\\r\\\\n)=" + literalBreak + " realCRLF=" + realCrlf + " realLF=" + realLf);
        String preview = content.substring(0, Math.min(160, len)).replaceAll("\\s+", " ");
        System.out.println("    preview: " + preview);
        Files.write(Paths.get(System.getProperty("java.io.tmpdir"), "dsh-content-sample.txt"), content.getBytes(StandardCharsets.UTF_8));
      }
      System.out.println("RESULT search=OK toc=OK content=" + (len > 100 ? "OK" : "SHORT"));
    } catch (Throwable e) {
      System.out.println("[4] content FAILED: " + chain(e));
      System.out.println("RESULT search=OK toc=OK content=FAIL");
    }
  }

  private static int countOccurrences(String haystack, String needle) {
    if (haystack == null || needle == null || needle.isEmpty()) {
      return 0;
    }
    int count = 0;
    int idx = 0;
    while ((idx = haystack.indexOf(needle, idx)) >= 0) {
      count++;
      idx += needle.length();
    }
    return count;
  }

  private static String chain(Throwable e) {
    StringBuilder sb = new StringBuilder();
    Throwable c = e;
    int i = 0;
    while (c != null && i++ < 6 && sb.length() < 600) {
      if (sb.length() > 0) {
        sb.append(" <- ");
      }
      sb.append(c.getClass().getSimpleName()).append(": ").append(String.valueOf(c.getMessage()));
      c = c.getCause();
    }
    return sb.toString();
  }
}
