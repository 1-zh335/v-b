package com.unclezs.novel.app.main.core;

import com.unclezs.novel.app.framework.executor.Executor;
import com.unclezs.novel.app.framework.support.hotkey.HotKeyCombination;
import com.unclezs.novel.app.framework.support.hotkey.HotKeyManager;
import com.unclezs.novel.app.main.manager.SettingManager;
import javafx.application.Platform;
import javafx.stage.Stage;
import javafx.stage.Window;

import java.util.ArrayList;
import java.util.List;

/**
 * 全局老板键：按一次隐藏全部窗口（连同托盘图标），再按一次恢复。
 *
 * <p>覆盖两种启动方式：
 * <ul>
 *   <li>完整版：{@code App.init()} 调用 {@link #install()}；</li>
 *   <li>本地TXT快速阅读：{@code QuickApp.init()} 调用 {@link #install()}（该模式无托盘，恢复只依赖热键）。</li>
 * </ul>
 *
 * <p>热键取自 {@code conf.hotkey.globalBossKey}，默认 {@code alt U}；注册失败时回退到默认键。
 * 隐藏前调用 {@code Platform.setImplicitExit(false)}，避免隐藏最后一个窗口导致应用退出。
 */
public final class BossKey {

  private static final java.util.logging.Logger LOG = java.util.logging.Logger.getLogger("BossKey");
  private static final List<Window> HIDDEN = new ArrayList<>();
  private static volatile boolean installed;
  private static volatile String stroke = "alt U";

  private BossKey() {
  }

  /**
   * 注册全局老板键（幂等）。
   */
  public static synchronized void install() {
    if (installed) {
      return;
    }
    installed = true;
    String configured = null;
    try {
      configured = SettingManager.manager().getHotkey().getGlobalBossKey();
    } catch (Throwable e) {
      LOG.warning("读取老板键配置失败: " + e);
    }
    String use = (configured == null || configured.trim().isEmpty()) ? "alt U" : configured.trim();
    boolean globalEnabled = true;
    try {
      globalEnabled = SettingManager.manager().getHotkey().isEnabledGlobal();
    } catch (Throwable e) {
      LOG.warning("读取全局热键开关失败: " + e);
    }
    if (!globalEnabled) {
      LOG.info("老板键未注册：设置中已关闭『启用全局快捷键』");
      return;
    }
    try {
      HotKeyManager.registerGlobal(HotKeyCombination.fromStroke(use), key -> toggle());
      stroke = use;
      LOG.info("老板键已注册: " + use);
    } catch (Throwable e) {
      LOG.warning("老板键注册失败(" + use + ")，尝试回退 alt U: " + e);
      try {
        HotKeyManager.registerGlobal(HotKeyCombination.fromStroke("alt U"), key -> toggle());
        stroke = "alt U";
        LOG.info("老板键回退注册成功: alt U");
      } catch (Throwable e2) {
        LOG.warning("老板键回退注册失败: " + e2);
      }
    }
  }

  /**
   * 当前老板键位文本（用于 UI 提示）。
   */
  public static String stroke() {
    return stroke;
  }

  public static boolean isInstalled() {
    return installed;
  }

  /**
   * 触发老板键切换（全局热键回调；也供设置界面测试按钮调用）。
   */
  public static void toggle() {
    Executor.runFx(BossKey::toggleFx);
  }

  private static void toggleFx() {
    Stage primary;
    try {
      primary = com.unclezs.novel.app.main.App.stage();
    } catch (Throwable t) {
      primary = null;
    }
    if (primary == null) {
      LOG.warning("老板键：主窗口不存在，忽略");
      return;
    }
    try {
      if (primary.isShowing()) {
        // 隐藏：先禁止隐式退出，再隐藏全部窗口与会托盘
        Platform.setImplicitExit(false);
        HIDDEN.clear();
        for (Window window : Window.getWindows()) {
          if (window.isShowing()) {
            HIDDEN.add(window);
          }
        }
        for (Window window : new ArrayList<>(HIDDEN)) {
          try {
            window.hide();
          } catch (Throwable e) {
            LOG.warning("老板键：隐藏窗口失败: " + e);
          }
        }
        try {
          com.unclezs.novel.app.main.manager.TrayManager.hide();
        } catch (Throwable ignored) {
          // 快速阅读模式未初始化托盘
        }
        LOG.info("老板键：已隐藏 " + HIDDEN.size() + " 个窗口");
      } else {
        // 恢复：显示隐藏前的全部窗口，并回到前台
        List<Window> toShow = new ArrayList<>(HIDDEN);
        if (HIDDEN.isEmpty()) {
          toShow.add(primary);
        }
        HIDDEN.clear();
        for (Window window : toShow) {
          try {
            showWindow(window);
          } catch (Throwable e) {
            LOG.warning("老板键：恢复窗口失败: " + e);
          }
        }
        try {
          if (!primary.isShowing()) {
            primary.show();
          }
          primary.toFront();
          primary.requestFocus();
        } catch (Throwable e) {
          LOG.warning("老板键：主窗口置前失败: " + e);
        }
        try {
          com.unclezs.novel.app.main.manager.TrayManager.tray();
        } catch (Throwable ignored) {
          // 快速阅读模式未初始化托盘
        }
        LOG.info("老板键：已恢复窗口");
      }
    } catch (Throwable e) {
      LOG.warning("老板键切换失败: " + e);
    }
  }

  /**
   * 重新安装（设置页开启『启用全局快捷键』后调用）：清标记后按当前配置重新注册。
   */
  public static synchronized void reinstall() {
    installed = false;
    install();
  }

  /**
   * 重置注册标记（设置页关闭全局快捷键时调用，框架已 clearGlobal）。
   */
  public static synchronized void reset() {
    installed = false;
    HIDDEN.clear();
    LOG.info("老板键已随全局快捷键关闭而失效");
  }

  /**
   * Window#show() 是 protected，只能按具体类型恢复；PopupWindow 需要位置参数，直接忽略（隐藏后无需恢复菜单）。
   */
  private static void showWindow(Window window) {
    if (window instanceof Stage) {
      ((Stage) window).show();
    }
  }
}
