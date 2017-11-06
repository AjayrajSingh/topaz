const RECONNECT_INTERVAL = 500;
const MAX_RECONNECT_INTERVAL = 2000;

var _activeAskQueryFlag = false;
var _entities = {};
var _focusedStoryId = null;
var _modules = {};
var _reconnectInterval = RECONNECT_INTERVAL;
var _stories = {};
var _toolbar = null;
var _tabBar = null;
var _webSocket = null;

$(function() {
  mdc.autoInit();
  _toolbar =
    new mdc.toolbar.MDCToolbar(document.querySelector('.mdc-toolbar'));
  _tabBar =
    new mdc.tabs.MDCTabBar(document.querySelector('#dashboard-tab-bar'));

  _tabBar.listen('MDCTabBar:change', function (t) {
      var newPanelSelector = _tabBar.activeTab.root_.hash;
      updateTabPanel(newPanelSelector);
    });

  _tabBar.layout();

})

function updateTabPanel(newPanelSelector) {
  var activePanel = document.querySelector('.panel.active');
  if (activePanel) {
    activePanel.classList.remove('active');
  }
  var newActivePanel = document.querySelector(newPanelSelector);
  if (newActivePanel) {
    newActivePanel.classList.add('active');
  }
}
