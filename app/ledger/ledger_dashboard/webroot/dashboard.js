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

  $(document).ready(function(){
    getInstancesList();
  });
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

function getInstancesList() {
  $.get("http://" + window.location.host + "/data/ledger_debug/instances_list",
        function(data, status){
          var instancesList = JSON.parse(JSON.stringify(data));
          $("#number-of-ledger-instances").append(instancesList.length);
          for(var i = 0; i < instancesList.length; i++) {
            var methodElem = $("<li></li>")
            .addClass('mdc-list-item')
            .text(instancesList[i]);

            $("#ledger-instances-list").append(methodElem);
          }
        });
}
