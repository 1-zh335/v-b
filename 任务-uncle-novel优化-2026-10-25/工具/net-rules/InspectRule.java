import com.unclezs.novel.analyzer.core.helper.RuleHelper;
import com.unclezs.novel.analyzer.core.model.AnalyzerRule;
import com.unclezs.novel.analyzer.core.model.ContentRule;
import com.unclezs.novel.analyzer.core.rule.CommonRule;
import com.unclezs.novel.analyzer.core.rule.ReplaceRule;

/**
 * 打印规则里 CommonRule 的解析结果，排查 replace 等字段是否被 analyzer 正确反序列化。
 *
 * <p>用法：java InspectRule &lt;rules.json&gt; [ruleIndex]
 */
public class InspectRule {

  public static void main(String[] args) throws Exception {
    if (args.length < 1) {
      System.out.println("usage: InspectRule <rules.json> [ruleIndex]");
      System.exit(2);
    }
    String json = new String(java.nio.file.Files.readAllBytes(java.nio.file.Paths.get(args[0])),
      java.nio.charset.StandardCharsets.UTF_8);
    RuleHelper.loadRules(json);
    int idx = args.length > 1 ? Integer.parseInt(args[1]) : 0;
    AnalyzerRule rule = RuleHelper.rules().get(idx);
    System.out.println("rule: " + rule.getName() + " site=" + rule.getSite());
    dump("content.content", rule.getContent() == null ? null : rule.getContent().getContent());
    dump("toc.list", rule.getToc() == null ? null : rule.getToc().getList());
    dump("toc.name", rule.getToc() == null ? null : rule.getToc().getName());
    dump("toc.url", rule.getToc() == null ? null : rule.getToc().getUrl());
    if (rule.getSearch() != null) {
      dump("search.list", rule.getSearch().getList());
      if (rule.getSearch().getDetail() != null) {
        dump("search.detail.url", rule.getSearch().getDetail().getUrl());
        dump("search.detail.author", rule.getSearch().getDetail().getAuthor());
      }
    }
    ContentRule cr = rule.getContent();
    if (cr != null && cr.getContent() != null && cr.getContent().getReplace() != null) {
      for (ReplaceRule rr : cr.getContent().getReplace()) {
        System.out.println("  replace from=[" + rr.getFrom() + "] to=[" + rr.getTo() + "]");
      }
    }
    // 原始 GSON 回写，确认 app 保存格式
    System.out.println("--- reserialized ---");
    System.out.println(RuleHelper.GSON.toJson(rule));
  }

  private static void dump(String label, CommonRule c) {
    if (c == null) {
      System.out.println("  " + label + " = <null>");
      return;
    }
    System.out.println("  " + label + " = {type=" + c.getType() + ", rule=" + c.getRule() + ", page=" + c.getPage()
      + ", script=" + (c.getScript() == null ? null : c.getScript().substring(0, Math.min(60, c.getScript().length()))) + "}");
  }
}
