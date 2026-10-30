package com.unclezs.novel.app.main.core.loader;

import cn.hutool.core.io.FileUtil;
import cn.hutool.core.io.IoUtil;
import cn.hutool.core.io.file.FileMode;
import cn.hutool.core.lang.PatternPool;
import com.unclezs.novel.analyzer.model.Chapter;
import com.unclezs.novel.analyzer.util.CollectionUtils;
import com.unclezs.novel.app.main.db.beans.Book;
import com.unclezs.novel.app.main.db.beans.TxtTocRule;
import com.unclezs.novel.app.main.manager.ResourceManager;
import com.unclezs.novel.app.main.util.EncodingDetect;

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 本地 TXT 加载器（增强版：章节索引磁盘缓存，重复打开秒开）。
 *
 * @author blog.unclezs.com（原始实现）
 */
public class TxtLoader extends AbstractBookLoader {

  private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger("TxtLoader");

  /**
   * 默认从文件中获取数据的长度
   */
  private static final int BUFFER_SIZE = 512 * 1024;
  /**
   * 没有标题的时候，每个章节的最大长度
   */
  private static final int MAX_LENGTH_WITH_NO_CHAPTER = 10 * 1024;
  private File bookFile;
  private String charset;

  /**
   * 检查文件中是否存在章节名，并判断应该使用哪一种章节规则。
   */
  public static int checkChapterType(File file, List<TxtTocRule> rules) {
    try (RandomAccessFile ras = FileUtil.createRandomAccessFile(file, FileMode.r)) {
      byte[] buffer = new byte[BUFFER_SIZE / 4];
      int length = ras.read(buffer, 0, buffer.length);
      int index = 0;
      for (TxtTocRule rule : rules) {
        Pattern pattern = PatternPool.get(rule.getRule(), Pattern.MULTILINE);
        Matcher matcher = pattern.matcher(new String(buffer, 0, length, EncodingDetect.getEncode(file)));
        if (matcher.find()) {
          ras.seek(0);
          return index;
        }
        index++;
      }
    } catch (Exception e) {
      log.error("解析TXT目录失败", e);
    }
    return -1;
  }

  @Override
  public void setBook(Book book) {
    super.setBook(book);
    this.bookFile = new File(getBook().getUrl());
    charset = this.getBook().getCharset();
    if (charset == null) {
      this.charset = EncodingDetect.getEncode(bookFile);
    }
    // GB2312/GBK 都是 GB18030 的子集；统一用超集解码，避免生僻字/乱码字符被替换成 '?'
    if (charset != null && ("GB2312".equalsIgnoreCase(charset) || "GBK".equalsIgnoreCase(charset)
      || "GB2312-80".equalsIgnoreCase(charset))) {
      charset = "GB18030";
    }
  }

  /**
   * 章节列表（带磁盘缓存：同一文件第二次打开直接读缓存）。
   */
  @Override
  public List<Chapter> toc() {
    if (CollectionUtils.isEmpty(toc)) {
      File cacheFile = indexCacheFile();
      List<Chapter> cached = loadIndexCache(cacheFile);
      if (cached != null && !cached.isEmpty()) {
        toc = cached;
        return toc;
      }
      try {
        toc = loadChapters(PatternPool.get(book.getTxtTocRule(), Pattern.MULTILINE));
        toc = postProcess(toc, bookFile.length());
        saveIndexCache(cacheFile, toc);
      } catch (IOException e) {
        log.error("本地小说章节解析失败：{}", bookFile, e);
        e.printStackTrace();
      }
    }
    return toc;
  }

  private File indexCacheFile() {
    String key = md5Hex(bookFile.getAbsolutePath());
    long size = bookFile.length();
    long modified = bookFile.lastModified();
    String charsetTag = charset == null ? "utf8" : charset.replace('-', '_');
    // 版本号：章节清洗/修复逻辑变更时递增，自动失效旧索引缓存
    return ResourceManager.cacheFile("txt-index/v5_" + key + "_" + size + "_" + modified + "_" + charsetTag + ".json");
  }

  private static String md5Hex(String text) {
    try {
      java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
      byte[] bytes = md.digest(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
      StringBuilder sb = new StringBuilder();
      for (byte b : bytes) {
        String hex = Integer.toHexString(b & 0xFF);
        if (hex.length() == 1) {
          sb.append('0');
        }
        sb.append(hex);
      }
      return sb.toString();
    } catch (Exception e) {
      return Integer.toHexString(text.hashCode());
    }
  }

  /**
   * 清洗章节名：修复「UTF-8 被当 GBK 显示」造成的乱码、去掉 === 包裹/书名前缀/水印后缀，
   * 修复失败则返回空串，由调用方用序号兜底。
   */
  private static String cleanName(String raw) {
    if (raw == null) {
      return "";
    }
    String name = raw.trim();
    int idx = name.indexOf('《');
    if (idx >= 0 && name.indexOf('》', idx) > idx) {
      name = name.substring(name.indexOf('》', idx) + 1).trim();
    }
    name = name.replaceAll("^=+\\s*|\\s*=+$", "").trim();
    int cut = name.indexOf("正在手打中");
    if (cut > 0) {
      name = name.substring(0, cut).trim();
    }
    cut = name.indexOf("免费阅读");
    if (cut > 0) {
      name = name.substring(0, cut).trim();
    }
    name = repairMojibake(name);
    // 去掉常见乱码残渣：竄17 / 丄17 / 亄17 等（原 UTF-8 字节丢失后的替代字符）
    name = name.replaceAll("[竄丄亄彄灄笄靄乄]\\d{0,3}", "");
    name = name.replaceAll("[^\u4e00-\u9fff0-9A-Za-z：:，,、（）()\\-\\s]", "").trim();
    // 去掉开头的「第X章/节」编号（标题栏会另行显示序号）
    name = name.replaceFirst("^第[0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}[章节回卷集部篇：:，,、\\s]*", "").trim();
    // 标题里的孤立数字多为乱码残渣
    name = name.replaceAll("\\s*\\d{1,3}\\s*", " ").trim();
    int han = 0;
    for (char c : name.toCharArray()) {
      if (c >= 0x4E00 && c <= 0x9FFF) {
        han++;
      }
    }
    if (han < 2) {
      return "";
    }
    if (name.length() > 40) {
      name = name.substring(0, 40);
    }
    return name;
  }

  /**
   * 尝试修复典型乱码：把「UTF-8 字节被 GBK 解读」的字符串还原。
   * 无论是否命中疑似字符都尝试一次，只有还原结果完全有效（无替换符/私用区）才采用。
   */
  private static String repairMojibake(String s) {
    if (s == null || s.isEmpty()) {
      return s;
    }
    try {
      byte[] bytes = s.getBytes("GB18030");
      String fixed = new String(bytes, java.nio.charset.StandardCharsets.UTF_8);
      fixed = fixed.replace("\uFFFD", "");
      fixed = fixed.replaceAll("[\\uE000-\\uF8FF]", "");
      int han = 0;
      for (char c : fixed.toCharArray()) {
        if (c >= 0x4E00 && c <= 0x9FFF) {
          han++;
        }
      }
      if (han >= 2) {
        return fixed;
      }
    } catch (Throwable e) {
      // ignore
    }
    return s;
  }

  /**
   * 去重 + 修正章节区间 + 生成干净的目录名（乱码不可恢复时用「第N章」兜底）。
   */
  private static List<Chapter> postProcess(List<Chapter> chapters, long fileLength) {
    if (chapters == null || chapters.isEmpty()) {
      return chapters;
    }
    List<Chapter> kept = new ArrayList<>();
    String lastRaw = null;
    for (Chapter ch : chapters) {
      // 只折叠「连续且原始标题完全相同」的重复行（水印重复）；标题修复失败的章节全部保留
      String raw = ch.getName() == null ? "" : ch.getName().trim();
      if (lastRaw != null && raw.equals(lastRaw)) {
        continue;
      }
      lastRaw = raw;
      kept.add(ch);
    }
    for (int i = 0; i < kept.size(); i++) {
      Chapter ch = kept.get(i);
      long from = ch.getFrom();
      long to = (i + 1 < kept.size()) ? kept.get(i + 1).getFrom() : fileLength;
      if (to < from) {
        to = from;
      }
      ch.setFrom(from);
      ch.setTo(to);
      ch.setOrder(i);
      String title = cleanName(ch.getName());
      if (title.isEmpty()) {
        title = cleanName(repairMojibake(ch.getName()));
      }
      if (title.matches("^(序章|楔子|前言|后记|尾声|番外|终章).*")) {
        ch.setName(title);
      } else {
        ch.setName(title.isEmpty() ? ("第" + (i + 1) + "章") : ("第" + (i + 1) + "章 " + title));
      }
    }
    return kept;
  }

  private List<Chapter> loadIndexCache(File cacheFile) {
    try {
      if (!cacheFile.exists() || cacheFile.length() <= 2) {
        return null;
      }
      String json = FileUtil.readUtf8String(cacheFile);
      List<Chapter> list = com.unclezs.novel.analyzer.util.GsonUtils.me().fromJson(json,
        new com.google.gson.reflect.TypeToken<List<Chapter>>() {
        }.getType());
      return list;
    } catch (Throwable e) {
      log.warn("读取章节索引缓存失败：{}", cacheFile, e);
      return null;
    }
  }

  private void saveIndexCache(File cacheFile, List<Chapter> chapters) {
    try {
      if (chapters == null || chapters.isEmpty()) {
        return;
      }
      File parent = cacheFile.getParentFile();
      if (parent != null && !parent.exists()) {
        parent.mkdirs();
      }
      FileUtil.writeUtf8String(com.unclezs.novel.analyzer.util.GsonUtils.me().toJson(chapters), cacheFile);
    } catch (Throwable e) {
      log.warn("写入章节索引缓存失败：{}", cacheFile, e);
    }
  }

  /**
   * 加载正文。
   */
  @Override
  public String loadContent(int index) {
    Chapter chapter = toc().get(index);
    try (RandomAccessFile ras = FileUtil.createRandomAccessFile(bookFile, FileMode.r)) {
      ras.seek(chapter.getFrom());
      byte[] bytes = new byte[(int) (chapter.getTo() - chapter.getFrom())];
      ras.read(bytes);
      String content = new String(bytes, charset);
      return cleanContent(content);
    } catch (IOException ioException) {
      ioException.printStackTrace();
    }
    return null;
  }

  /**
   * 清洗正文：去掉水印行（=== 包裹的标题行、本站来源行、广告行），保留正常段落。
   */
  private static String cleanContent(String content) {
    if (content == null) {
      return null;
    }
    String text = content.replace("\r\n", "\n");
    StringBuilder sb = new StringBuilder(text.length());
    for (String line : text.split("\n", -1)) {
      String trim = line.trim();
      if (trim.matches("^=+.*=+$")) {
        continue;
      }
      if (trim.startsWith("本文件来自") || trim.startsWith("鏈功鏉ヨ嚜") || trim.startsWith("更多精彩小说")
        || trim.matches("^第?[0-9]{0,4}\\s*[章节]?\\s*$") && trim.isEmpty()) {
        continue;
      }
      sb.append(line).append('\n');
    }
    return sb.toString().replaceAll("\\n{3,}", "\n\n").trim();
  }

  @Override
  public boolean isCached(int index) {
    return true;
  }

  public boolean checkHasChapter(RandomAccessFile bookStream, Pattern pattern) throws IOException {
    byte[] buffer = new byte[BUFFER_SIZE / 4];
    int length = bookStream.read(buffer, 0, buffer.length);
    Matcher matcher = pattern.matcher(new String(buffer, 0, length, charset));
    if (matcher.find()) {
      bookStream.seek(0);
      return true;
    }
    bookStream.seek(0);
    return false;
  }

  /**
   * 按正则扫描全文件，生成章节起止字节偏移。
   */
  public List<Chapter> loadChapters(Pattern pattern) throws IOException {
    List<Chapter> toc = new ArrayList<>();
    RandomAccessFile bookStream = FileUtil.createRandomAccessFile(bookFile, FileMode.r);
    boolean hasChapter = checkHasChapter(bookStream, pattern);
    byte[] buffer = new byte[BUFFER_SIZE];
    long curOffset = 0;
    int blockPos = 0;
    int length;
    while ((length = bookStream.read(buffer, 0, buffer.length)) > 0) {
      ++blockPos;
      if (hasChapter) {
        String blockContent = new String(buffer, 0, length, charset);
        int lastN = blockContent.lastIndexOf("\n");
        if (lastN > 0) {
          blockContent = blockContent.substring(0, lastN);
          length = blockContent.getBytes(charset).length;
          long newPos = curOffset + length;
          bookStream.seek(newPos);
        }
        int seekPos = 0;
        Matcher matcher = pattern.matcher(blockContent);
        while (matcher.find()) {
          int chapterStart = matcher.start();
          if (seekPos == 0 && chapterStart != 0) {
            String chapterContent = blockContent.substring(seekPos, chapterStart);
            seekPos += chapterContent.length();
            if (toc.isEmpty()) {
              Chapter chapter = new Chapter();
              chapter.setName(matcher.group());
              chapter.setFrom((long) chapterContent.getBytes(charset).length);
              toc.add(chapter);
            } else {
              Chapter lastChapter = toc.get(toc.size() - 1);
              lastChapter.setTo(lastChapter.getTo() + chapterContent.getBytes(charset).length);
              lastChapter.setFrom(lastChapter.getFrom() + lastChapter.getName().getBytes(charset).length);
              Chapter curChapter = new Chapter();
              curChapter.setName(matcher.group());
              curChapter.setFrom(lastChapter.getTo());
              toc.add(curChapter);
            }
          } else {
            if (!toc.isEmpty()) {
              String chapterContent = blockContent.substring(seekPos, matcher.start());
              seekPos += chapterContent.length();
              Chapter lastChapter = toc.get(toc.size() - 1);
              lastChapter.setTo(lastChapter.getFrom() + chapterContent.getBytes(charset).length);
              lastChapter.setFrom(lastChapter.getFrom() + lastChapter.getName().getBytes(charset).length);
              Chapter curChapter = new Chapter();
              curChapter.setName(matcher.group());
              curChapter.setFrom(lastChapter.getTo());
              toc.add(curChapter);
            } else {
              Chapter curChapter = new Chapter();
              curChapter.setName(matcher.group());
              curChapter.setFrom(0L);
              curChapter.setTo(0L);
              toc.add(curChapter);
            }
          }
        }
      } else {
        int chapterOffset = 0;
        int strLength = length;
        int chapterPos = 0;
        while (strLength > 0) {
          ++chapterPos;
          if (strLength > MAX_LENGTH_WITH_NO_CHAPTER) {
            int end = length;
            for (int i = chapterOffset + MAX_LENGTH_WITH_NO_CHAPTER; i < length; ++i) {
              if (buffer[i] == 0x0a) {
                end = i;
                break;
              }
            }
            Chapter chapter = new Chapter();
            chapter.setName("第" + blockPos + "章" + "(" + chapterPos + ")");
            chapter.setFrom(curOffset + chapterOffset + 1);
            chapter.setTo(curOffset + end);
            toc.add(chapter);
            strLength = strLength - (end - chapterOffset);
            chapterOffset = end;
          } else {
            Chapter chapter = new Chapter();
            chapter.setName("第" + blockPos + "章" + "(" + chapterPos + ")");
            chapter.setFrom(curOffset + chapterOffset + 1);
            chapter.setTo(curOffset + length);
            toc.add(chapter);
            strLength = 0;
          }
        }
      }
      curOffset += length;
      if (hasChapter) {
        Chapter lastChapter = toc.get(toc.size() - 1);
        lastChapter.setTo(curOffset);
      }
      if (blockPos % 15 == 0) {
        System.gc();
        System.runFinalization();
      }
    }
    for (int i = 0; i < toc.size(); i++) {
      toc.get(i).setOrder(i);
    }
    IoUtil.close(bookStream);
    return toc;
  }
}
