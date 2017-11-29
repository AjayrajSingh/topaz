var _toolbar = null;
var _tabBar = null;
var _webSocket = null;
var _ReqUrl = "http://" + window.location.host + "/data/ledger_debug";

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
});

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


var app = angular.module('ledgerDashboard', []);
app.controller('debugCtrl', function($scope, $http) {
  $scope.instancesList = [];
  $scope.pagesList = [];
  $scope.showPages = false;
  $scope.selectedInstance = '';
  $scope.bytesToString = function(bytesList) {
    var str = "";
    for(var i = 0; i < bytesList.length; i++) {
      if((bytesList[i] >= 0 && bytesList[i] <= 31)
          || bytesList[i] >= 127) {
        str = bytesToHex(bytesList);
        break;
      }
      str += String.fromCharCode(bytesList[i]);
    }
    return str;
  };

  function bytesToHex (bytes) {
    var hexString = '0x';
    for(var i = 0; i < bytes.length; i++) {
      var temp = bytes[i].toString(16);
      if(temp.length < 2)
        temp = "0" + temp;
      hexString += temp;
    }
    return hexString;
  };

  $scope.getPagesList = function(index) {
    $scope.selectedInstance = $scope.bytesToString($scope.instancesList[index]);
    $scope.showPages = true;
    $http.get( _ReqUrl + "/pages_list",{
      params: { instance: JSON.stringify($scope.instancesList[index]) }
    })
      .then(function(response) {
        $scope.pagesList = response.data;
      });
  };

  $(document).ready(function(){
    $http.get( _ReqUrl + "/instances_list").then(function(response){
      $scope.instancesList = response.data;
    });
  });
});
