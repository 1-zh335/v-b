package com.unclezs.novel.app.main.core;

import com.unclezs.novel.app.framework.components.StageDecorator;
import com.unclezs.novel.app.framework.components.Toast;
import javafx.application.Platform;
import javafx.beans.property.ReadOnlyObjectProperty;
import javafx.beans.property.ReadOnlyObjectWrapper;
import javafx.scene.control.Alert;
import javafx.scene.control.ButtonBar;
import javafx.scene.control.ButtonType;
import javafx.stage.Stage;

import javax.sound.sampled.AudioSystem;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * 离线/联网状态守卫。
 *
 * <p>面向「仅偶尔可联网」的目标机（DTPC953）：
 * <ul>
 *   <li>后台探测网络（默认 HEAD https://www.baidu.com/，可配置），在线 60s / 离线 15s 复检；</li>
 *   <li>状态变化通过 JavaFX 属性通知 UI（标题、提示）；</li>
 *   <li>联网功能被点击时由各视图调用 {@link #guardNetwork(String)}，离线则弹出统一说明框；</li>
 *   <li>{@link #guardAudio(String)} 检测音频设备（目标机未安装声卡驱动）；</li>
 *   <li>{@link #isAnalyticsDisabled()} 在目标档/离线时禁用 MixPanel 埋点。</li>
 * </ul>
 *
 * <p>可用系统属性（测试/部署）：
 * <pre>
 * -Duncle.target.profile=true              目标机低配档（离线提示更积极、埋点关闭）
 * -Duncle.network.force=auto|online|offline 强制联网状态（测试用）
 * -Duncle.network.probe.url=...            探测 URL
 * -Duncle.network.interval.online.ms=60000 在线复检间隔
 * -Duncle.network.interval.offline.ms=15000 离线复检间隔
 * -Duncle.network.timeout.ms=3000
 * -Duncle.audio.force=auto|available|unavailable
 * -Duncle.analytics.disabled=true
 * </pre>
 */
public final class OfflineGuard {

  public enum State {
    /** 正在检测 */
    CHECKING,
    /** 在线 */
    ONLINE,
    /** 离线 */
    OFFLINE
  }

  private static final java.util.logging.Logger LOG = java.util.logging.Logger.getLogger("OfflineGuard");
  private static final boolean TARGET_PROFILE = Boolean.getBoolean("uncle.target.profile");
  private static final ReadOnlyObjectWrapper<State> STATE = new ReadOnlyObjectWrapper<>(State.CHECKING);
  private static final Object AUDIO_LOCK = new Object();
  private static volatile boolean started;
  private static volatile boolean running = true;
  private static volatile boolean offlineToastShown;
  private static volatile Boolean audioAvailable;

  private OfflineGuard() {
  }

  /**
   * 启动状态探测线程（幂等）。
   */
  public static void start() {
    if (started) {
      return;
    }
    started = true;
    running = true;
    Thread thread = new Thread(OfflineGuard::probeLoop, "offline-guard");
    thread.setDaemon(true);
    thread.start();
    // 诊断/验收开关：启动后自动弹出对应提示框（用于离线/无声卡 UI 验收）
    if (Boolean.getBoolean("uncle.offline.demo")) {
      scheduleDemo(() -> guardNetwork("书源搜索"), 2500L);
    }
    if (Boolean.getBoolean("uncle.audio.demo")) {
      scheduleDemo(() -> showAudioDialog("朗读"), 3200L);
    }
    LOG.info("离线守卫已启动（targetProfile=" + TARGET_PROFILE + "，force="
      + System.getProperty("uncle.network.force", "auto") + "）");
  }

  /**
   * 诊断用：延迟在 FX 线程执行一次动作。
   */
  private static void scheduleDemo(Runnable action, long delayMs) {
    Thread thread = new Thread(() -> {
      try {
        Thread.sleep(delayMs);
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        return;
      }
      Platform.runLater(action);
    }, "offline-guard-demo");
    thread.setDaemon(true);
    thread.start();
  }

  /**
   * 停止探测（主要给测试/退出用）。
   */
  public static void stop() {
    running = false;
    started = false;
  }

  public static State state() {
    return STATE.get();
  }

  public static boolean isOffline() {
    return STATE.get() == State.OFFLINE;
  }

  public static boolean isOnline() {
    return STATE.get() == State.ONLINE;
  }

  public static boolean isChecking() {
    return STATE.get() == State.CHECKING;
  }

  public static ReadOnlyObjectProperty<State> stateProperty() {
    return STATE.getReadOnlyProperty();
  }

  public static boolean isTargetProfile() {
    return TARGET_PROFILE;
  }

  /**
   * 目标档 / 离线 / 显式关闭时不做联网埋点。
   */
  public static boolean isAnalyticsDisabled() {
    return Boolean.getBoolean("uncle.analytics.disabled") || TARGET_PROFILE || isOffline();
  }

  /**
   * 联网功能守卫：非在线状态弹出离线说明框并返回 true（调用方直接 return）。
   *
   * @param feature 功能名（如「书源搜索」）
   */
  public static boolean guardNetwork(String feature) {
    if (isOnline()) {
      return false;
    }
    final String name = normalize(feature);
    Platform.runLater(() -> showNetworkDialog(name));
    return true;
  }

  /**
   * 音频功能守卫：无音频设备时弹提示并返回 true。
   */
  public static boolean guardAudio(String feature) {
    if (hasAudioDevice()) {
      return false;
    }
    final String name = normalize(feature);
    Platform.runLater(() -> showAudioDialog(name));
    return true;
  }

  /**
   * TTS 守卫：先音频、再网络。
   */
  public static boolean guardTts(String feature) {
    if (guardAudio(feature)) {
      return true;
    }
    return guardNetwork(feature);
  }

  /**
   * 是否存在可用音频输出设备（结果缓存；支持强制属性用于测试）。
   */
  public static boolean hasAudioDevice() {
    Boolean forced = forcedAudio();
    if (forced != null) {
      return forced;
    }
    Boolean cached = audioAvailable;
    if (cached != null) {
      return cached;
    }
    synchronized (AUDIO_LOCK) {
      if (audioAvailable == null) {
        boolean available;
        try {
          available = AudioSystem.getMixerInfo().length > 0;
        } catch (Throwable e) {
          available = false;
        }
        audioAvailable = available;
        LOG.info("音频设备检测: " + (available ? "可用" : "未检测到"));
      }
      return audioAvailable;
    }
  }

  /**
   * 标题后缀（阅读器用）。
   */
  public static String titleSuffix() {
    return isOffline() ? " · 离线" : "";
  }

  /**
   * 主页/窗口标题（完整版用）。
   */
  public static String homeTitle() {
    return isOffline() ? "Uncle小说（离线）" : "Uncle小说";
  }

  /**
   * 绑定 StageDecorator 标题，随联网状态刷新。
   */
  public static void bindTitle(StageDecorator decorator, String baseTitle) {
    if (decorator == null) {
      return;
    }
    final String base = baseTitle == null ? "Uncle小说" : baseTitle;
    decorator.setTitle(composeTitle(base));
    STATE.addListener((obs, oldValue, newValue) -> Platform.runLater(() -> decorator.setTitle(composeTitle(base))));
  }

  /**
   * 绑定原生 Stage 标题（快速阅读模式用）。
   */
  public static void bindWindowTitle(Stage stage, String baseTitle) {
    if (stage == null) {
      return;
    }
    final String base = baseTitle == null ? "Uncle小说" : baseTitle;
    stage.setTitle(composeTitle(base));
    STATE.addListener((obs, oldValue, newValue) -> Platform.runLater(() -> stage.setTitle(composeTitle(base))));
  }

  /**
   * 主动探测一次（后台线程），完成后回调（FX 线程）。
   */
  public static void probeNowAsync(Runnable onDone) {
    Thread thread = new Thread(() -> {
      boolean online = probe();
      Platform.runLater(() -> {
        setStateQuietly(online ? State.ONLINE : State.OFFLINE);
        if (onDone != null) {
          onDone.run();
        }
      });
    }, "offline-guard-probe");
    thread.setDaemon(true);
    thread.start();
  }

  // ------------------------------------------------------------------
  // 内部实现
  // ------------------------------------------------------------------

  private static void probeLoop() {
    while (running) {
      boolean online = probe();
      setStateQuietly(online ? State.ONLINE : State.OFFLINE);
      long interval = online
        ? Long.getLong("uncle.network.interval.online.ms", 60000L)
        : Long.getLong("uncle.network.interval.offline.ms", 15000L);
      try {
        Thread.sleep(Math.max(3000L, interval));
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        return;
      }
    }
  }

  private static void setStateQuietly(State next) {
    State current = STATE.get();
    if (current == next) {
      return;
    }
    State previous = current;
    STATE.set(next);
    LOG.info("联网状态: " + previous + " -> " + next);
    if (next == State.OFFLINE) {
      if (!offlineToastShown && isWindowReady()) {
        offlineToastShown = true;
        Platform.runLater(() -> safeToastWarn("离线模式：本地阅读可用；联网功能需网络，恢复后自动启用"));
      }
    } else if (next == State.ONLINE && previous == State.OFFLINE) {
      Platform.runLater(() -> safeToastSuccess("网络已恢复，在线功能已启用"));
    }
  }

  private static boolean probe() {
    String force = System.getProperty("uncle.network.force", "auto").trim().toLowerCase();
    if ("offline".equals(force)) {
      return false;
    }
    if ("online".equals(force)) {
      return true;
    }
    String urlStr = System.getProperty("uncle.network.probe.url", "https://www.baidu.com/");
    int timeout = Integer.getInteger("uncle.network.timeout.ms", 3000);
    HttpURLConnection connection = null;
    try {
      URL url = new URL(urlStr);
      connection = (HttpURLConnection) url.openConnection();
      connection.setRequestMethod("HEAD");
      connection.setConnectTimeout(timeout);
      connection.setReadTimeout(timeout);
      connection.setInstanceFollowRedirects(true);
      connection.setRequestProperty("User-Agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) UncleNovel-OfflineCheck");
      int code = connection.getResponseCode();
      return code > 0 && code < 500;
    } catch (Throwable e) {
      return false;
    } finally {
      if (connection != null) {
        connection.disconnect();
      }
    }
  }

  private static void showNetworkDialog(String feature) {
    try {
      LOG.info("离线提示框已弹出: " + feature);
      Alert alert = new Alert(Alert.AlertType.NONE);
      alert.setTitle("离线模式");
      alert.setHeaderText("「" + feature + "」需要网络连接");
      alert.setContentText("当前未检测到可用网络（本机为间歇联网环境）。\n\n"
        + "可继续使用的功能：\n"
        + "· 本地 TXT 快速阅读\n"
        + "· 导入本地小说（本地文件）\n"
        + "· 书架与阅读进度\n\n"
        + "网络恢复后在线功能会自动启用，无需重启。");
      ButtonType retry = new ButtonType("重试联网", ButtonBar.ButtonData.OTHER);
      ButtonType close = new ButtonType("继续离线", ButtonBar.ButtonData.CANCEL_CLOSE);
      alert.getButtonTypes().setAll(retry, close);
      alert.getDialogPane().setMinWidth(460);
      initOwner(alert);
      alert.showAndWait().ifPresent(button -> {
        if (button == retry) {
          retryProbe();
        }
      });
    } catch (Throwable e) {
      LOG.warning("显示离线提示框失败: " + e);
    }
  }

  private static void showAudioDialog(String feature) {
    try {
      LOG.info("音频提示框已弹出: " + feature);
      Alert alert = new Alert(Alert.AlertType.NONE);
      alert.setTitle("音频不可用");
      alert.setHeaderText("「" + feature + "」需要音频设备");
      alert.setContentText("当前设备未检测到可用音频设备（目标机未安装声卡驱动）。\n\n"
        + "朗读 / 有声播放暂不可用；本地阅读、书架、下载都不受影响。");
      ButtonType close = new ButtonType("知道了", ButtonBar.ButtonData.CANCEL_CLOSE);
      alert.getButtonTypes().setAll(close);
      alert.getDialogPane().setMinWidth(420);
      initOwner(alert);
      alert.showAndWait();
    } catch (Throwable e) {
      LOG.warning("显示音频提示框失败: " + e);
    }
  }

  private static void retryProbe() {
    Thread thread = new Thread(() -> {
      boolean online = probe();
      Platform.runLater(() -> {
        setStateQuietly(online ? State.ONLINE : State.OFFLINE);
        if (online) {
          safeToastSuccess("网络已连接，在线功能已恢复");
        } else {
          safeToastWarn("仍未检测到网络，本地阅读不受影响");
        }
      });
    }, "offline-guard-retry");
    thread.setDaemon(true);
    thread.start();
  }

  private static String composeTitle(String base) {
    return isOffline() ? base + "（离线）" : base;
  }

  private static Boolean forcedAudio() {
    String value = System.getProperty("uncle.audio.force", "auto").trim().toLowerCase();
    if ("available".equals(value)) {
      return Boolean.TRUE;
    }
    if ("unavailable".equals(value)) {
      return Boolean.FALSE;
    }
    return null;
  }

  private static String normalize(String feature) {
    return (feature == null || feature.trim().isEmpty()) ? "该功能" : feature.trim();
  }

  private static boolean isWindowReady() {
    try {
      Stage stage = com.unclezs.novel.app.main.App.stage();
      return stage != null && stage.isShowing();
    } catch (Throwable e) {
      return false;
    }
  }

  private static void initOwner(Alert alert) {
    try {
      Stage stage = com.unclezs.novel.app.main.App.stage();
      if (stage != null) {
        alert.initOwner(stage);
      }
    } catch (Throwable ignored) {
      // 无窗口时忽略
    }
  }

  private static void safeToastWarn(String message) {
    try {
      Toast.warn(message);
    } catch (Throwable e) {
      LOG.warning("离线提示 Toast 失败: " + e);
    }
  }

  private static void safeToastSuccess(String message) {
    try {
      Toast.success(message);
    } catch (Throwable e) {
      LOG.warning("恢复提示 Toast 失败: " + e);
    }
  }
}
