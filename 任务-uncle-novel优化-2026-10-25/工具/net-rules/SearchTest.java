import com.unclezs.novel.analyzer.core.helper.RuleHelper;
import com.unclezs.novel.analyzer.core.model.AnalyzerRule;
import com.unclezs.novel.analyzer.core.NovelMatcher;
import com.unclezs.novel.analyzer.model.Novel;
import com.unclezs.novel.analyzer.request.Http;
import com.unclezs.novel.analyzer.request.HttpConfig;
import com.unclezs.novel.analyzer.request.okhttp.OkHttpClient;
import com.unclezs.novel.analyzer.request.spi.HttpProvider;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 用应用自带的 novel-analyzer.jar 做「书源搜索」端到端实测。
 *
 * <p>这是最接近 app 内「全网搜书」行为的验证：加载规则 → 用 NovelMatcher.search 真正发请求、
 * 走 XPath/JSONPath/JS 匹配、拿回 Novel 列表。可区分「规则能解析」与「规则能搜出书」。
 *
 * <p>用法：java SearchTest &lt;rules.json&gt; &lt;keyword&gt; &lt;out.json&gt; [siteRegex] [maxRules]
 * <ul>
 *   <li>out.json：UTF-8 结果文件（每条规则一行 JSON 对象）</li>
 *   <li>siteRegex：只测 site 匹配该正则的规则；默认全部文本规则</li>
 *   <li>maxRules：最多测几条，默认 100</li>
 * </ul>
 *
 * <p>退出码 0=执行完成（不代表每条规则都成功），2=参数错误。</p>
 */
public class SearchTest {

  public static void main(String[] args) throws Exception {
    if (args.length < 3) {
      System.out.println("usage: SearchTest <rules.json> <keyword> <out.json> [siteRegex] [maxRules]");
      System.exit(2);
    }
    Path rulesFile = Paths.get(args[0]);
    String keyword = args[1];
    Path outFile = Paths.get(args[2]);
    Pattern siteFilter = args.length > 3 && !args[3].isEmpty() ? Pattern.compile(args[3]) : null;
    int maxRules = args.length > 4 ? Integer.parseInt(args[4]) : 100;

    String json = new String(Files.readAllBytes(rulesFile), StandardCharsets.UTF_8);
    RuleHelper.loadRules(json);
    List<AnalyzerRule> all = new ArrayList<>(RuleHelper.rules());
    System.out.println("== loaded rules: " + all.size() + " keyword=" + keyword);

    // 缩短超时，避免个别站点把整轮拖死（单位：秒）
    HttpProvider provider = Http.getStaticHttpClient();
    if (provider instanceof OkHttpClient) {
      HttpConfig config = HttpConfig.defaultConfig();
      config.setConnectionTimeout(10);
      config.setReadTimeout(15);
      config.setFollowRedirect(true);
      config.setRetryOnFailed(false);
      ((OkHttpClient) provider).configuration(config);
      System.out.println("== http config: connect=10s read=15s");
    }

    List<String> resultLines = new ArrayList<>();
    int tested = 0;
    int okCount = 0;
    for (AnalyzerRule rule : all) {
      String site = rule.getSite() == null ? "" : rule.getSite();
      if (siteFilter != null && !siteFilter.matcher(site).find()) {
        continue;
      }
      if (Boolean.TRUE.equals(rule.getAudio())) {
        continue;
      }
      if (tested >= maxRules) {
        break;
      }
      tested++;
      long t0 = System.currentTimeMillis();
      int count = 0;
      List<String> titles = new ArrayList<>();
      String error = "";
      try {
        List<Novel> novels = NovelMatcher.search(1, keyword, rule, novel -> {
        });
        if (novels != null) {
          count = novels.size();
          for (int i = 0; i < Math.min(3, novels.size()); i++) {
            Novel n = novels.get(i);
            titles.add((n.getTitle() == null ? "" : n.getTitle().trim()) + " | " + (n.getAuthor() == null ? "" : n.getAuthor())
              + " | " + (n.getUrl() == null ? "" : n.getUrl()));
          }
        }
      } catch (Throwable e) {
        Throwable c = e;
        StringBuilder sb = new StringBuilder();
        while (c != null && sb.length() < 300) {
          if (sb.length() > 0) {
            sb.append(" <- ");
          }
          sb.append(c.getClass().getSimpleName()).append(": ").append(String.valueOf(c.getMessage()));
          c = c.getCause();
        }
        error = sb.toString();
      }
      long ms = System.currentTimeMillis() - t0;
      if (count > 0) {
        okCount++;
      }
      String line = "{"
        + "\"site\":" + q(site)
        + ",\"name\":" + q(rule.getName())
        + ",\"count\":" + count
        + ",\"ms\":" + ms
        + ",\"error\":" + q(error)
        + ",\"titles\":[" + joinQ(titles) + "]}";
      resultLines.add(line);
      System.out.println("[TEST] site=" + site + " name=" + rule.getName() + " count=" + count + " ms=" + ms
        + (error.isEmpty() ? "" : " error=" + error));
      for (String t : titles) {
        System.out.println("        > " + t);
      }
    }
    Files.write(outFile, ("[\n" + String.join(",\n", resultLines) + "\n]\n").getBytes(StandardCharsets.UTF_8));
    System.out.println("== SUMMARY tested=" + tested + " hasResults=" + okCount + " -> " + outFile.toAbsolutePath());
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

  private static String joinQ(List<String> items) {
    StringBuilder b = new StringBuilder();
    for (int i = 0; i < items.size(); i++) {
      if (i > 0) {
        b.append(',');
      }
      b.append(q(items.get(i)));
    }
    return b.toString();
  }
}
