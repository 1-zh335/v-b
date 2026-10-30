package com.unclezs.novel.app.main.manager;

import com.unclezs.novel.analyzer.util.StringUtils;
import com.unclezs.novel.app.framework.executor.Executor;
import com.unclezs.novel.app.framework.support.hotkey.HotKeyCombination;
import com.unclezs.novel.app.framework.support.hotkey.HotKeyManager;
import com.unclezs.novel.app.main.App;
import com.unclezs.novel.app.main.model.config.HotKeyConfig;

/**
 * @author blog.unclezs.com
 * @since 2021/6/2 20:05
 */
public class HotkeyManager {
  private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger("HotkeyManager");

  /**
   * 触发老板键（统一委托给 BossKey，完整版与快速阅读模式一致）。
   */
  public static void triggerBossKey() {
    com.unclezs.novel.app.main.core.BossKey.toggle();
  }

  /**
   * 初始化热键
   */
  public static void init() {
    HotKeyConfig config = SettingManager.manager().getHotkey();
    if (StringUtils.isNotBlank(config.getReaderNextChapter())) {
      HotKeyManager.registerWindowHotkey(HotKeyCombination.fromStroke(config.getReaderNextChapter()));
    }
    if (StringUtils.isNotBlank(config.getReaderToc())) {
      HotKeyManager.registerWindowHotkey(HotKeyCombination.fromStroke(config.getReaderToc()));
    }
    if (StringUtils.isNotBlank(config.getReaderNextPage())) {
      HotKeyManager.registerWindowHotkey(HotKeyCombination.fromStroke(config.getReaderNextPage()));
    }
    if (StringUtils.isNotBlank(config.getReaderPreChapter())) {
      HotKeyManager.registerWindowHotkey(HotKeyCombination.fromStroke(config.getReaderPreChapter()));
    }
    if (StringUtils.isNotBlank(config.getReaderPrePage())) {
      HotKeyManager.registerWindowHotkey(HotKeyCombination.fromStroke(config.getReaderPrePage()));
    }
    // 老板键统一由 BossKey 注册（设置页开启「启用全局快捷键」时会重新调用本方法）
    com.unclezs.novel.app.main.core.BossKey.reinstall();
  }

  public static void destroy() {
    com.unclezs.novel.app.main.core.BossKey.reset();
    HotKeyManager.clearGlobal();
  }
}
