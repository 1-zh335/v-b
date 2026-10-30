package com.unclezs.novel.app.main.views.home;

import com.jfoenix.controls.JFXProgressBar;
import com.unclezs.novel.analyzer.model.Novel;
import com.unclezs.novel.app.framework.annotation.FxView;
import com.unclezs.novel.app.framework.components.SearchBar;
import com.unclezs.novel.app.framework.components.SearchBar.SearchEvent;
import com.unclezs.novel.app.framework.components.icon.IconButton;
import com.unclezs.novel.app.framework.components.sidebar.SidebarNavigateBundle;
import com.unclezs.novel.app.framework.components.sidebar.SidebarView;
import com.unclezs.novel.app.framework.util.EventUtils;
import com.unclezs.novel.app.framework.util.NodeHelper;
import com.unclezs.novel.app.main.core.NovelSearcher;
import com.unclezs.novel.app.main.core.NovelSearcher.Callback;
import com.unclezs.novel.app.main.core.OfflineGuard;
import com.unclezs.novel.app.main.enums.SearchType;
import com.unclezs.novel.app.main.util.MixPanelHelper;
import com.unclezs.novel.app.main.views.components.BookDetailModal;
import com.unclezs.novel.app.main.views.components.BookDetailModal.Action;
import com.unclezs.novel.app.main.views.components.cell.BookListCell;
import javafx.fxml.FXML;
import javafx.scene.control.ListView;
import javafx.scene.control.ScrollBar;
import javafx.scene.layout.StackPane;

/**
 * 搜索小说页面
 *
 * @author blog.unclezs.com
 * @since 2021/02/27 17:16
 */
@FxView(fxml = "/layout/home/search-novel.fxml")
public class SearchNovelView extends SidebarView<StackPane> implements Callback {

  private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger("SearchNovelView");

  private static final String PAGE_NAME = "搜索小说";
  @FXML
  private JFXProgressBar loadingBar;
  @FXML
  private IconButton loading;
  @FXML
  private ListView<Novel> listView;
  @FXML
  private SearchBar searchBar;
  private ScrollBar scrollBar;
  private NovelSearcher novelSearcher;

  @Override
  public void onShown(SidebarNavigateBundle bundle) {
    searchBar.focus();
  }

  @Override
  public void onCreated() {
    searchBar.addTypes(SearchType.ALL.getDesc(), SearchType.NAME.getDesc(), SearchType.AUTHOR.getDesc());
    listView.setCellFactory(BookListCell::new);
    // 单机查看详情
    EventUtils.setOnMousePrimaryClick(listView, event -> {
      if (!listView.getSelectionModel().isEmpty()) {
        Novel novel = listView.getSelectionModel().getSelectedItem();
        new BookDetailModal(novel).withActions(Action.BOOKSHELF, Action.ANALYSIS, Action.DOWNLOAD).show();
      }
    });
    loading.setOnAction(e -> novelSearcher.cancel());
  }

  @Override
  public void onShow(SidebarNavigateBundle bundle) {
    MixPanelHelper.event(PAGE_NAME);
  }

  /**
   * 点击搜索
   *
   * @param event 搜索事件
   */
  @FXML
  private void search(SearchEvent event) {
    // 书源搜索依赖网络，离线时统一拦截并提示
    if (OfflineGuard.guardNetwork("书源搜索")) {
      return;
    }
    listView.getItems().clear();
    if (novelSearcher == null) {
      novelSearcher = new NovelSearcher(false, this);
    }
    novelSearcher.doSearch(event.getInput(), event.getType());
  }

  /**
   * 加载更多数据
   */
  public void loadMore() {
    if (scrollBar.getValue() != 1 || !novelSearcher.isHasMore() || novelSearcher.isSearching()) {
      return;
    }
    // 加载更多
    scrollBar.setValue(1 - 0.00001);
    novelSearcher.loadMore();
  }

  @Override
  public void showLoading(boolean show) {
    if (show) {
      loading.setVisible(true);
      loading.setManaged(true);
      loadingBar.setVisible(true);
    } else {
      loading.setVisible(false);
      loading.setManaged(false);
      loadingBar.setVisible(false);
    }
  }

  @Override
  public void addItem(Novel novel) {
    listView.getItems().add(novel);
    // 获取滚动条，用于滚动到底部加载更多
    if (scrollBar == null) {
      scrollBar = NodeHelper.findVBar(listView);
      scrollBar.valueProperty().addListener(e -> loadMore());
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
    if (!(o instanceof SearchNovelView)) {
      return false;
    }
    SearchNovelView other = (SearchNovelView) o;
    if (!other.canEqual(this)) {
      return false;
    }
    if (!super.equals(o)) {
      return false;
    }
    return java.util.Objects.equals(this.loadingBar, other.loadingBar)
      && java.util.Objects.equals(this.loading, other.loading)
      && java.util.Objects.equals(this.listView, other.listView)
      && java.util.Objects.equals(this.searchBar, other.searchBar)
      && java.util.Objects.equals(this.scrollBar, other.scrollBar)
      && java.util.Objects.equals(this.novelSearcher, other.novelSearcher);
  }

  protected boolean canEqual(Object other) {
    return other instanceof SearchNovelView;
  }

  @Override
  public int hashCode() {
    int result = super.hashCode();
    result = result * 59 + (this.loadingBar == null ? 43 : this.loadingBar.hashCode());
    result = result * 59 + (this.loading == null ? 43 : this.loading.hashCode());
    result = result * 59 + (this.listView == null ? 43 : this.listView.hashCode());
    result = result * 59 + (this.searchBar == null ? 43 : this.searchBar.hashCode());
    result = result * 59 + (this.scrollBar == null ? 43 : this.scrollBar.hashCode());
    result = result * 59 + (this.novelSearcher == null ? 43 : this.novelSearcher.hashCode());
    return result;
  }
}
