package com.unclezs.novel.app.main;

import cn.hutool.core.io.FileUtil;
import cn.hutool.core.util.IdUtil;
import com.unclezs.novel.app.framework.appication.SceneNavigateBundle;
import com.unclezs.novel.app.framework.appication.SceneView;
import com.unclezs.novel.app.framework.components.Toast;
import com.unclezs.novel.app.main.core.loader.TxtLoader;
import com.unclezs.novel.app.main.db.beans.Book;
import com.unclezs.novel.app.main.db.dao.BookDao;
import com.unclezs.novel.app.main.manager.SettingManager;
import com.unclezs.novel.app.main.util.EncodingDetect;
import com.unclezs.novel.app.main.views.reader.ReaderView;
import javafx.application.Platform;
import javafx.scene.control.Label;
import javafx.scene.layout.Region;
import javafx.scene.layout.StackPane;
import javafx.stage.FileChooser;
import javafx.stage.Stage;

import java.io.File;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 本地 TXT 快速阅读入口：继承官方 App，启动后直接打开传入的 TXT 文件（或弹出文件选择框），
 * 自动识别编码与章节规则、后台建立章节索引，然后进入官方阅读器（每章独立分页）。
 *
 * 设计目标：解决官方 5.0.44 只能通过「导入本地小说 → 预览 → 加入书架」繁琐路径阅读本地 TXT 的问题；
 * 相当于把旧版 4.x 的「打开即读」体验合并进 5.0.44。
 */
public class QuickApp extends App {

  /** 章节规则候选（按优先级），选匹配数最多的一个 */
  private static final String[] RULE_CANDIDATES = {
    // 素材常见格式：=== 第X章 标题 ===
    "^\\s*={2,}.*={2,}\\s*$",
    // 标准：第X章 标题
    "^[ \\t\\u3000]{0,4}第[0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}[章节回卷集部篇][^\\n]{0,80}$",
    // 带书名： 《书名》第X章 标题
    "^.*《[^》]{1,30}》[ \\t\\u3000]{0,4}第[0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}[章节回卷][^\\n]{0,80}$",
    // 数字标题： 1、标题 / 1. 标题
    "^[ \\t\\u3000]{0,4}(?:第)?[0-9]{1,5}[、.．,，][^\\n]{1,60}$"
  };

  private static final java.util.logging.Logger LOG = java.util.logging.Logger.getLogger("QuickApp");

  /** 轻量欢迎页（代替官方首页，加快本地 TXT 打开） */
  private SceneView<? extends Region> splashView;

  public static void main(String[] args) {
    launch(args);
  }

  /**
   * 精简初始化：本地快速阅读不需要托盘、全局热键和自定义字体，跳过可明显缩短启动时间。
   */
  @Override
  public void init() throws Exception {
    Thread.currentThread().setName("FX");
    SettingManager.init();
    LOG.info("快速阅读模式：已跳过托盘/全局热键/自定义字体初始化");
  }

  /**
   * 用轻量欢迎页代替官方首页（官方首页含侧边栏、网络任务等，初始化较慢）。
   */
  @Override
  public SceneView<? extends Region> getIndexView() {
    if (splashView == null) {
      splashView = new SplashView();
    }
    return splashView;
  }

  /**
   * 启动画面：仅一个居中提示，随后立即被阅读器替换。
   */
  static class SplashView extends SceneView<StackPane> {
    SplashView() {
      StackPane pane = new StackPane();
      pane.setPrefSize(420, 160);
      pane.setMinSize(420, 160);
      pane.setStyle("-fx-background-color: #ceebce;");
      Label label = new Label("Uncle小说 · 本地 TXT 快速阅读");
      label.setStyle("-fx-font-size: 18px; -fx-text-fill: #2f4050; -fx-font-family: 'Microsoft YaHei';");
      pane.getChildren().add(label);
      setRoot(pane);
    }
  }

  @Override
  public void start(Stage stage) throws Exception {
    super.start(stage);
    String file = null;
    List<String> raw = getParameters().getRaw();
    if (!raw.isEmpty()) {
      file = raw.get(0);
    }
    if (file == null || file.isBlank() || !new File(file).isFile()) {
      FileChooser chooser = new FileChooser();
      chooser.setTitle("选择要阅读的 TXT 文件");
      chooser.getExtensionFilters().add(new FileChooser.ExtensionFilter("文本文件 (*.txt)", "*.txt"));
      File home = new File(System.getProperty("user.home"));
      if (home.isDirectory()) {
        chooser.setInitialDirectory(home);
      }
      File chosen = chooser.showOpenDialog(stage);
      if (chosen == null) {
        return;
      }
      file = chosen.getAbsolutePath();
    }
    openLocalTxt(new File(file));
  }

  /**
   * 打开本地 TXT：识别编码/章节规则 → 写书架数据库 → 后台建索引 → 进入阅读器。
   */
  private void openLocalTxt(File file) {
    final String path = file.getAbsolutePath();
    Toast.info("正在打开：" + file.getName());
    Thread worker = new Thread(() -> {
      try {
        String charset = EncodingDetect.getEncode(path);
        String rule = pickRule(file, charset);
        BookDao bookDao = new BookDao();
        Book book = bookDao.selectAll().stream()
          .filter(b -> b.isLocal() && path.equals(b.getUrl()))
          .findFirst()
          .orElseGet(() -> {
            Book b = new Book(path, charset);
            b.setId(IdUtil.fastSimpleUUID());
            b.setName(FileUtil.mainName(file));
            b.setLocal(true);
            b.setCurrentChapterIndex(0);
            b.setCurrentPage(0);
            return b;
          });
        book.setCharset(charset);
        book.setTxtTocRule(rule);
        book.setLocal(true);
        if (book.getName() == null || book.getName().isBlank()) {
          book.setName(FileUtil.mainName(file));
        }
        // 先解析章节（首次会写入磁盘索引缓存）
        TxtLoader loader = new TxtLoader();
        loader.setBook(book);
        long begin = System.currentTimeMillis();
        int size = loader.toc().size();
        long cost = System.currentTimeMillis() - begin;
        LOG.info("章节索引完成：" + size + " 章，耗时 " + cost + "ms，" + path);
        // 无封面时按书名生成一张封面（书架显示书名，封面与书名一致）
        generateCover(book);
        // 入库（保留阅读进度）
        if (book.getToc() == null) {
          if (bookDao.selectAll().stream().anyMatch(b -> b.getId().equals(book.getId()))) {
            bookDao.update(book);
          } else {
            bookDao.save(book);
          }
        }
        Platform.runLater(() -> {
          SceneNavigateBundle bundle = new SceneNavigateBundle();
          bundle.put(ReaderView.BUNDLE_READ_BOOK_KEY, book);
          navigate(ReaderView.class, bundle);
          Toast.success("已打开：" + file.getName() + "（" + size + " 章）");
        });
      } catch (Throwable e) {
        LOG.severe("打开本地TXT失败: " + e);
        e.printStackTrace();
        Platform.runLater(() -> Toast.error("打开失败：" + e.getMessage()));
      }
    }, "quick-open");
    worker.setDaemon(true);
    worker.start();
  }

  /**
   * 选择章节规则：读取文件头部 512KB，统计各候选规则命中行数，取命中最多者。
   */
  private String pickRule(File file, String charset) {
    try {
      byte[] head = new byte[512 * 1024];
      int read;
      try (java.io.RandomAccessFile raf = new java.io.RandomAccessFile(file, "r")) {
        read = raf.read(head);
      }
      String text = new String(head, 0, Math.max(read, 0), charset);
      int best = -1;
      int bestScore = 0;
      for (int i = 0; i < RULE_CANDIDATES.length; i++) {
        Pattern p = Pattern.compile(RULE_CANDIDATES[i], Pattern.MULTILINE);
        Matcher m = p.matcher(text);
        int score = 0;
        while (m.find()) {
          score++;
          if (score > 5000) {
            break;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = i;
        }
      }
      if (best >= 0 && bestScore >= 3) {
        return RULE_CANDIDATES[best];
      }
    } catch (Throwable e) {
      LOG.warning("章节规则识别失败，使用虚拟分章: " + e);
    }
    // 无章节：用永不匹配的规则触发 10KB 虚拟分章
    return "\\u0000";
  }

  /**
   * 按书名生成一张 300x380 的封面图（渐变底 + 居中书名 + 底部署名），保存到
   * caches/book/&lt;书籍ID&gt;/cover.jpeg 并写入 book.cover（本地路径）。
   * 书架 BookNode 通过 ImageLoader 支持本地文件路径，直接显示该封面。
   */
  private void generateCover(Book book) {
    try {
      String existing = book.getCover();
      if (existing != null && !existing.isEmpty() && new File(existing).exists()) {
        return;
      }
      String name = book.getName() == null ? "未命名" : book.getName();
      int w = 300;
      int h = 380;
      java.awt.image.BufferedImage image = new java.awt.image.BufferedImage(w, h,
        java.awt.image.BufferedImage.TYPE_INT_RGB);
      java.awt.Graphics2D g = image.createGraphics();
      g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING,
        java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
      g.setRenderingHint(java.awt.RenderingHints.KEY_TEXT_ANTIALIASING,
        java.awt.RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
      // 护眼绿渐变底
      g.setPaint(new java.awt.GradientPaint(0, 0, new java.awt.Color(0x2E, 0x4A, 0x3A), 0, h,
        new java.awt.Color(0xCE, 0xEB, 0xCE)));
      g.fillRect(0, 0, w, h);
      // 内边框
      g.setColor(new java.awt.Color(0x39, 0x3D, 0x49));
      g.setStroke(new java.awt.BasicStroke(3f));
      g.drawRect(8, 8, w - 17, h - 17);
      // 书名自动换行（中文按字宽估算）
      int fontSize = name.length() > 18 ? 26 : 32;
      g.setFont(new java.awt.Font("Microsoft YaHei", java.awt.Font.BOLD, fontSize));
      g.setColor(java.awt.Color.WHITE);
      java.awt.FontMetrics fm = g.getFontMetrics();
      int maxWidth = w - 60;
      java.util.List<String> lines = new java.util.ArrayList<>();
      StringBuilder line = new StringBuilder();
      for (char c : name.toCharArray()) {
        if (fm.stringWidth(line.toString() + c) > maxWidth && line.length() > 0) {
          lines.add(line.toString());
          line.setLength(0);
        }
        line.append(c);
      }
      if (line.length() > 0) {
        lines.add(line.toString());
      }
      if (lines.size() > 6) {
        lines = new java.util.ArrayList<>(lines.subList(0, 6));
        String last = lines.get(5);
        lines.set(5, (last.length() > 2 ? last.substring(0, last.length() - 1) : last) + "…");
      }
      int lineHeight = fm.getHeight() + 6;
      int totalHeight = lines.size() * lineHeight;
      int startY = (h - totalHeight) / 2 - 20 + fm.getAscent();
      for (int i = 0; i < lines.size(); i++) {
        String text = lines.get(i);
        int x = (w - fm.stringWidth(text)) / 2;
        g.drawString(text, x, startY + i * lineHeight);
      }
      // 底部小字
      g.setFont(new java.awt.Font("Microsoft YaHei", java.awt.Font.PLAIN, 14));
      g.setColor(new java.awt.Color(0xCE, 0xEB, 0xCE));
      String footer = "Uncle小说 · 本地TXT";
      java.awt.FontMetrics fm2 = g.getFontMetrics();
      g.drawString(footer, (w - fm2.stringWidth(footer)) / 2, h - 30);
      g.dispose();
      File dir = cn.hutool.core.io.FileUtil.file(
        com.unclezs.novel.app.main.manager.ResourceManager.cacheFile("book"), book.getId());
      dir.mkdirs();
      File cover = new File(dir, "cover.jpeg");
      javax.imageio.ImageIO.write(image, "jpeg", cover);
      book.setCover(cover.getAbsolutePath());
      LOG.info("已生成书名封面: " + cover.getAbsolutePath());
    } catch (Throwable e) {
      LOG.warning("生成封面失败（不影响阅读）: " + e);
    }
  }
}
