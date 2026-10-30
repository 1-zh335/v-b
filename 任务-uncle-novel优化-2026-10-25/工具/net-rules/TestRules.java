import com.unclezs.novel.analyzer.core.helper.RuleHelper;
import com.unclezs.novel.analyzer.core.model.AnalyzerRule;
import com.unclezs.novel.analyzer.core.model.SearchRule;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * 用应用自带的 novel-analyzer.jar 验证书源规则文件是否能被 RuleHelper 正常加载。
 *
 * <p>用法：java TestRules &lt;rules.json&gt; [dump.json]
 * <ul>
 *   <li>rules.json：待验证规则文件（JSON 数组）</li>
 *   <li>dump.json：可选，把 RuleHelper 解析后的规则用 GSON 重新序列化落盘，用于核对 app 实际写回格式</li>
 * </ul>
 *
 * <p>输出：loadRules 返回值、RuleHelper.rules() 数量、每条规则 isEffective / search.isEffective。</p>
 */
public class TestRules {

  public static void main(String[] args) throws Exception {
    if (args.length < 1) {
      System.out.println("usage: TestRules <rules.json> [dump.json]");
      System.exit(2);
    }
    Path in = Paths.get(args[0]);
    String json = new String(Files.readAllBytes(in), StandardCharsets.UTF_8);
    System.out.println("== file: " + in.toAbsolutePath());
    System.out.println("== bytes: " + json.getBytes(StandardCharsets.UTF_8).length);
    System.out.println("== first char: " + (json.isEmpty() ? "<empty>" : json.trim().substring(0, 1)));

    int loaded = RuleHelper.loadRules(json);
    List<AnalyzerRule> rules = RuleHelper.rules();
    System.out.println("== loadRules() returns: " + loaded);
    System.out.println("== RuleHelper.rules().size(): " + rules.size());

    int effective = 0;
    int searchEffective = 0;
    int enabledEffective = 0;
    for (int i = 0; i < rules.size(); i++) {
      AnalyzerRule r = rules.get(i);
      boolean eff = r.isEffective();
      SearchRule s = r.getSearch();
      boolean se = s != null && s.isEffective();
      if (eff) effective++;
      if (se) searchEffective++;
      if (eff && Boolean.TRUE.equals(r.getEnabled())) enabledEffective++;
      String url = (s == null || s.getParams() == null) ? null : s.getParams().getUrl();
      System.out.println("[" + i + "] name=" + r.getName()
        + " | site=" + r.getSite()
        + " | enabled=" + r.getEnabled()
        + " | audio=" + r.getAudio()
        + " | weight=" + r.getWeight()
        + " | isEffective=" + eff
        + " | searchEffective=" + se
        + " | searchUrl=" + url);
    }
    System.out.println("== SUMMARY effective=" + effective
      + " searchEffective=" + searchEffective
      + " enabled&effective=" + enabledEffective);

    if (args.length > 1) {
      String dumped = RuleHelper.GSON.toJson(rules);
      Files.write(Paths.get(args[1]), dumped.getBytes(StandardCharsets.UTF_8));
      System.out.println("== dump -> " + Paths.get(args[1]).toAbsolutePath() + " bytes=" + dumped.getBytes(StandardCharsets.UTF_8).length);
    }
  }
}
