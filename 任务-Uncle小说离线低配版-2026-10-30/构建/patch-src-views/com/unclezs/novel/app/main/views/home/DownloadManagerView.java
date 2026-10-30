package com.unclezs.novel.app.main.views.home;

import cn.hutool.core.io.FileUtil;
import com.unclezs.novel.analyzer.model.Novel;
import com.unclezs.novel.analyzer.spider.Spider;
import com.unclezs.novel.app.framework.annotation.FxView;
import com.unclezs.novel.app.framework.components.PlaceHolder;
import com.unclezs.novel.app.framework.components.TabButton;
import com.unclezs.novel.app.framework.components.Toast;
import com.unclezs.novel.app.framework.components.icon.Icon;
import com.unclezs.novel.app.framework.components.icon.IconFont;
import com.unclezs.novel.app.framework.components.sidebar.SidebarNavigateBundle;
import com.unclezs.novel.app.framework.components.sidebar.SidebarView;
import com.unclezs.novel.app.framework.serialize.PropertyJsonSerializer;
import com.unclezs.novel.app.framework.util.NodeHelper;
import com.unclezs.novel.app.main.core.OfflineGuard;
import com.unclezs.novel.app.main.core.spider.SpiderWrapper;
import com.unclezs.novel.app.main.db.beans.DownloadHistory;
import com.unclezs.novel.app.main.db.dao.DownloadHistoryDao;
import com.unclezs.novel.app.main.manager.ResourceManager;
import com.unclezs.novel.app.main.manager.SettingManager;
import com.unclezs.novel.app.main.model.BookBundle;
import com.unclezs.novel.app.main.model.config.DownloadConfig;
import com.unclezs.novel.app.main.util.MixPanelHelper;
import com.unclezs.novel.app.main.views.components.cell.DownloadActionTableCell;
import com.unclezs.novel.app.main.views.components.cell.DownloadHistoryActionTableCell;
import com.unclezs.novel.app.main.views.components.cell.ProgressBarTableCell;
import com.unclezs.novel.app.main.views.components.cell.TagsTableCell;
import javafx.beans.Observable;
import javafx.beans.property.ReadOnlyObjectWrapper;
import javafx.collections.ListChangeListener;
import javafx.event.ActionEvent;
import javafx.fxml.FXML;
import javafx.scene.Node;
import javafx.scene.control.ContextMenu;
import javafx.scene.control.MenuItem;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.layout.Priority;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * @author blog.unclezs.com
 * @since 2021/4/25 9:40
 */
@FxView(fxml = "/layout/home/download-manager.fxml")
public class DownloadManagerView extends SidebarView<StackPane> {

  private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger("DownloadManagerView");

  /**
   * 要下载的小说
   */
  public static final String BUNDLE_DOWNLOAD_KEY = "bundle_download_key";
  public static final File TMP_DIR = ResourceManager.cacheFile("downloads");
  private static final String PAGE_NAME = "下载管理";
  /**
   * 下载历史DAO
   */
  private final DownloadHistoryDao historyDao = new DownloadHistoryDao();
  @FXML
  private TabButton tasksTab;
  @FXML
  private TabButton historyTab;
  @FXML
  private VBox tasksPanel;
  private VBox historyPanel;
  @FXML
  private TableView<SpiderWrapper> tasksTable;
  private TableView<DownloadHistory> historyTable;
  @FXML
  private StackPane container;

  @Override
  public void onCreated() {
    createTasksTableColumns();
    restore();
    // 最大任务数量控制
    tasksTable.getItems().addListener((Observable observable) -> runTask());
    SettingManager.manager().getDownload().getTaskNum().addListener(e -> runTask());
    historyTab.setOnAction(e -> container.getChildren().setAll(getHistoryPanel()));
    tasksTab.setOnAction(e -> container.getChildren().setAll(tasksPanel));
  }

  @Override
  public void onShow(SidebarNavigateBundle bundle) {
    MixPanelHelper.event(PAGE_NAME);
    BookBundle bookBundle = bundle.get(BUNDLE_DOWNLOAD_KEY);
    if (bookBundle != null) {
      tasksTab.fireEvent(new ActionEvent());
      createTask(bookBundle);
    }
  }

  @Override
  public void onDestroy() {
    if (tasksTable.getItems().isEmpty()) {
      FileUtil.del(TMP_DIR);
    }
  }

  /**
   * 创建下载历史面板
   */
  private Node getHistoryPanel() {
    if (historyPanel == null) {
      historyPanel = new VBox(getHistoryTable());
    }
    return historyPanel;
  }

  /**
   * 获取下载历史表格，不存在则创建
   *
   * @return 下载历史表格
   */
  @SuppressWarnings("unchecked")
  private TableView<DownloadHistory> getHistoryTable() {
    if (historyTable == null) {
      historyTable = new TableView<>();
      historyTable.setPlaceholder(new PlaceHolder(localized("download.manager.history.placeholder")));
      VBox.setVgrow(historyTable, Priority.ALWAYS);
      historyTable.getItems().setAll(historyDao.selectAll());
      historyTable.getItems().addListener((ListChangeListener<DownloadHistory>) c -> {
        while (c.next()) {
          c.getRemoved().forEach(historyDao::delete);
          c.getAddedSubList().forEach(historyDao::save);
        }
      });
      // 序号
      TableColumn<DownloadHistory, Integer> id = NodeHelper.addClass(new TableColumn<>("#"), "id");
      id.prefWidthProperty().bind(historyTable.widthProperty().multiply(0.1));
      id.setCellValueFactory(
        param -> new ReadOnlyObjectWrapper<>(historyTable.getItems().indexOf(param.getValue()) + 1));
      // 名称
      TableColumn<DownloadHistory, String> name = new TableColumn<>(localized("download.manager.history.name"));
      name.prefWidthProperty().bind(historyTable.widthProperty().multiply(0.3));
      name.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(param.getValue().getName()));
      // 类型
      TableColumn<DownloadHistory, String> type = new TableColumn<>(localized("download.manager.history.type"));
      type.prefWidthProperty().bind(historyTable.widthProperty().multiply(0.25));
      type.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(param.getValue().getType()));
      type.setCellFactory(param -> new TagsTableCell<>());

      TableColumn<DownloadHistory, String> date = new TableColumn<>(localized("download.manager.history.date"));
      date.prefWidthProperty().bind(historyTable.widthProperty().multiply(0.2));
      date.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(param.getValue().getDate()));
      // 操作
      TableColumn<DownloadHistory, DownloadHistory> operation =
        NodeHelper.addClass(new TableColumn<>(localized("download.manager.history.operation")), "align-center");
      operation.prefWidthProperty().bind(historyTable.widthProperty().multiply(0.1));
      operation.setCellValueFactory(col -> new ReadOnlyObjectWrapper<>(col.getValue()));
      operation.setCellFactory(param -> new DownloadHistoryActionTableCell());

      historyTable.getColumns().addAll(id, name, type, date, operation);
      historyTable.getColumns().forEach(column -> column.setResizable(false));
      ContextMenu contextMenu = new ContextMenu();
      MenuItem clearHistory = new MenuItem("清空下载历史", new Icon(IconFont.DELETE));
      clearHistory.setOnAction(e -> historyTable.getItems().clear());
      contextMenu.getItems().add(clearHistory);
      historyTable.setContextMenu(contextMenu);
    }
    return historyTable;
  }

  /**
   * 创建下载任务列表表格
   */
  @SuppressWarnings("unchecked")
  private void createTasksTableColumns() {
    // 序号
    TableColumn<SpiderWrapper, Integer> id = NodeHelper.addClass(new TableColumn<>("#"), "id");
    id.prefWidthProperty().bind(tasksTable.widthProperty().multiply(0.1));
    id.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(tasksTable.getItems().indexOf(param.getValue()) + 1));
    // 名称
    TableColumn<SpiderWrapper, String> name = new TableColumn<>(localized("download.manager.running.name"));
    name.prefWidthProperty().bind(tasksTable.widthProperty().multiply(0.35));
    name.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(param.getValue().getName()));
    // 进度
    TableColumn<SpiderWrapper, SpiderWrapper> progress =
      new TableColumn<>(localized("download.manager.running.progress"));
    progress.prefWidthProperty().bind(tasksTable.widthProperty().multiply(0.35));
    progress.setCellValueFactory(param -> new ReadOnlyObjectWrapper<>(param.getValue()));
    progress.setCellFactory(param -> new ProgressBarTableCell());
    // 操作
    TableColumn<SpiderWrapper, SpiderWrapper> operation =
      NodeHelper.addClass(new TableColumn<>(localized("download.manager.running.operation")), "download-action-col");
    operation.prefWidthProperty().bind(tasksTable.widthProperty().multiply(0.15));
    operation.setCellValueFactory(col -> new ReadOnlyObjectWrapper<>(col.getValue()));
    operation.setCellFactory(param -> new DownloadActionTableCell());

    tasksTable.getColumns().addAll(id, name, progress, operation);
    tasksTable.getColumns().forEach(column -> column.setResizable(false));
  }

  /**
   * 处理完成后
   */
  public void onCompleted(SpiderWrapper wrapper) {
    // 删除缓存
    FileUtil.del(FileUtil.file(DownloadManagerView.TMP_DIR, wrapper.getId()));
    // 移除任务
    tasksTable.getItems().remove(wrapper);
    // 保存下载历史，不存在下载历史页面则直接入库
    DownloadHistory downloadHistory = DownloadHistory.fromWrapper(wrapper);
    if (historyTable != null) {
      historyTable.getItems().add(downloadHistory);
    } else {
      historyDao.save(downloadHistory);
    }
  }

  /**
   * 启动任务，限制设置的任务数量
   */
  public void runTask() {
    // 添加新的任务
    int canRunTasksNumber = canRunTasksNumber();
    if (canRunTasksNumber > 0) {
      // 等待中的任务
      List<SpiderWrapper> waitingTask = tasksTable.getItems().stream()
        .filter(task -> task.isState(SpiderWrapper.WAIT_RUN))
        .collect(Collectors.toList());
      for (int i = 0; i < canRunTasksNumber && i < waitingTask.size(); i++) {
        waitingTask.get(i).run();
      }
      // 任务数量超过了，则让超出的任务等待执行
    } else if (canRunTasksNumber < 0) {
      List<SpiderWrapper> runningTask = tasksTable.getItems().stream()
        .filter(task -> task.getSpider().isState(Spider.RUNNING))
        .collect(Collectors.toList());
      for (int i = canRunTasksNumber; i < 0 && runningTask.size() + i >= 0; i++) {
        runningTask.get(runningTask.size() + i).waiting();
      }
    }
  }

  /**
   * 创建下载任务
   *
   * @param bundle 下载数据包
   */
  private void createTask(BookBundle bundle) {
    // 下载任务的开始/继续依赖网络：本页接收下载数据包即开始下载，离线时统一拦截并提示。
    // 注：任务表格行内的「开始/暂停」按钮由 DownloadActionTableCell 直接调用 SpiderWrapper，不经过本类。
    if (OfflineGuard.guardNetwork("下载")) {
      return;
    }
    DownloadConfig downloadConfig = SettingManager.manager().getDownload();
    String savePath = downloadConfig.getFolder().getValue();
    if (!FileUtil.mkdir(savePath).exists()) {
      Toast.error("下载文件夹不存在，请在设置中更换");
      return;
    }
    Novel novel = bundle.getNovel();
    Spider spider = new Spider();
    spider.setUrl(novel.getUrl());
    spider.setNovel(bundle.getNovel());
    spider.setAnalyzerRule(bundle.getRule());
    spider.setRetryTimes(downloadConfig.getRetryNum().getValue());
    spider.setSavePath(savePath);
    spider.setThreadNum(downloadConfig.getThreadNum().getValue());
    SpiderWrapper spiderWrapper = new SpiderWrapper(spider, this::onCompleted);
    tasksTable.getItems().add(spiderWrapper);
    // 如果还有任务数量剩余则直接启动
    if (canRunTasksNumber() > 0) {
      spiderWrapper.run();
    }
  }

  /**
   * 剩余可以运行的任务数量
   *
   * @return 任务数量
   */
  public int canRunTasksNumber() {
    Integer maxTaskNum = SettingManager.manager().getDownload().getTaskNum().get();
    long currentRunning = tasksTable.getItems().stream().filter(task -> task.isState(Spider.RUNNING)).count();
    return (int) (maxTaskNum - currentRunning);
  }


  /**
   * 从临时文件中恢复下载任务
   */
  public void restore() {
    if (FileUtil.exist(TMP_DIR)) {
      List<String> names = FileUtil.listFileNames(TMP_DIR.getAbsolutePath());
      List<SpiderWrapper> tasks = new ArrayList<>();
      for (String name : names) {
        File file = FileUtil.file(TMP_DIR, name);
        try {
          String json = FileUtil.readUtf8String(file);
          SpiderWrapper task = PropertyJsonSerializer.fromJson(json, SpiderWrapper.class);
          task.setId(name);
          task.init(this::onCompleted);
          task.pause();
          tasks.add(task);
        } catch (Exception e) {
          log.warn("加载下载任务备份失败：{}", file.getAbsoluteFile(), e);
          FileUtil.del(file);
        }
      }
      tasksTable.getItems().setAll(tasks);
    }
  }

  // ------------------------------------------------------------------
  // 以下 equals/hashCode/canEqual 为 lombok @EqualsAndHashCode(callSuper = true)
  // 去 lombok 后手工展开的等价实现（逐实例字段比较，hashCode 与 lombok 同一算法）。
  // ------------------------------------------------------------------

  @Override
  public boolean equals(Object o) {
    if (o == this) {
      return true;
    }
    if (!(o instanceof DownloadManagerView)) {
      return false;
    }
    DownloadManagerView other = (DownloadManagerView) o;
    if (!other.canEqual(this)) {
      return false;
    }
    if (!super.equals(o)) {
      return false;
    }
    return java.util.Objects.equals(this.historyDao, other.historyDao)
      && java.util.Objects.equals(this.tasksTab, other.tasksTab)
      && java.util.Objects.equals(this.historyTab, other.historyTab)
      && java.util.Objects.equals(this.tasksPanel, other.tasksPanel)
      && java.util.Objects.equals(this.historyPanel, other.historyPanel)
      && java.util.Objects.equals(this.tasksTable, other.tasksTable)
      && java.util.Objects.equals(this.historyTable, other.historyTable)
      && java.util.Objects.equals(this.container, other.container);
  }

  protected boolean canEqual(Object other) {
    return other instanceof DownloadManagerView;
  }

  @Override
  public int hashCode() {
    int result = super.hashCode();
    result = result * 59 + (this.historyDao == null ? 43 : this.historyDao.hashCode());
    result = result * 59 + (this.tasksTab == null ? 43 : this.tasksTab.hashCode());
    result = result * 59 + (this.historyTab == null ? 43 : this.historyTab.hashCode());
    result = result * 59 + (this.tasksPanel == null ? 43 : this.tasksPanel.hashCode());
    result = result * 59 + (this.historyPanel == null ? 43 : this.historyPanel.hashCode());
    result = result * 59 + (this.tasksTable == null ? 43 : this.tasksTable.hashCode());
    result = result * 59 + (this.historyTable == null ? 43 : this.historyTable.hashCode());
    result = result * 59 + (this.container == null ? 43 : this.container.hashCode());
    return result;
  }
}
