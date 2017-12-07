const RECONNECT_INTERVAL = 500;
const MAX_RECONNECT_INTERVAL = 2000;

var _toolbar = null;
var _tabBar = null;
var _webSocket = null;
var _ReqUrl = 'http://' + window.location.host + '/data/ledger_debug';
var _reconnectInterval = RECONNECT_INTERVAL;

$(function() {
  mdc.autoInit();
  _toolbar = new mdc.toolbar.MDCToolbar(document.querySelector('.mdc-toolbar'));
  _tabBar =
      new mdc.tabs.MDCTabBar(document.querySelector('#dashboard-tab-bar'));

  _tabBar.listen('MDCTabBar:change', function(t) {
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
  $scope.commitsList = [];
  $scope.entriesList = [];
  $scope.showPages = false;
  $scope.showCommits = false;
  $scope.showEntries = false;
  $scope.selectedInstIndex = -1;
  $scope.selectedPageIndex = -1;
  $scope.selectedCommitIndex = -1;

  $scope.bytesToBase64 = function(bytes) {
    var str = '';
    for (i = 0; i < bytes.length; i++)
      str += String.fromCharCode(bytes[i]);
    return window.btoa(str);
  };


  $scope.bytesToString = function(bytesList) {
    var str = '';
    for (var i = 0; i < bytesList.length; i++) {
      if ((bytesList[i] >= 0 && bytesList[i] <= 31) || bytesList[i] >= 127) {
        str = bytesToHex(bytesList);
        break;
      }
      str += String.fromCharCode(bytesList[i]);
    }
    return str;
  };


  function bytesToHex(bytes) {
    var hexString = '0x';
    for (var i = 0; i < bytes.length; i++)
      hexString += bytes[i].toString(16);

    return hexString;
  };

  $scope.getPagesList = function(index) {
    $scope.selectedInstIndex = index;
    _webSocket.send(
        JSON.stringify({'instance_name': $scope.instancesList[index]}));
  };

  $scope.getCommitsList = function(index) {
    $scope.selectedPageIndex = index;
    _webSocket.send(JSON.stringify({'page_name': $scope.pagesList[index]}));
  };

  $scope.getEntriesList = function(index) {
    $scope.selectedCommitIndex = index;
    _webSocket.send(JSON.stringify({'commit_id': $scope.commitsList[index]}));
    $scope.entriesList = [];
  };

  function connectWebSocket() {
    $scope.showPages = false;
    _webSocket =
        new WebSocket('ws://' + window.location.host + '/ws/ledger_debug/');
    _webSocket.onopen = handleWebSocketOpen;
    _webSocket.onerror = handleWebSocketError;
    _webSocket.onclose = handleWebSocketClose;
    _webSocket.onmessage = handleWebSocketMessage;
  }

  function handleWebSocketOpen(evt) {
    $('#connectedLabel').text('Connected');
    // reset reconnect
    _reconnectInterval = RECONNECT_INTERVAL;
  }

  function handleWebSocketError(evt) {
    console.log('WebSocket Error: ' + evt.toString());
  }

  function handleWebSocketClose(evt) {
    $('#connectedLabel').text('Disconnected');
    // attempt to reconnect
    attemptReconnect();
  }

  function attemptReconnect() {
    console.log('Attempting to reconnect after ' + _reconnectInterval);

    // reconnect after the timeout
    setTimeout(connectWebSocket, _reconnectInterval);
    // exponential reconnect timeout
    var nextInterval = _reconnectInterval * 2;
    if (nextInterval < MAX_RECONNECT_INTERVAL) {
      _reconnectInterval = nextInterval;
    } else {
      _reconnectInterval = MAX_RECONNECT_INTERVAL;
    }
  }

  function handleWebSocketMessage(evt) {
    // parse the JSON message
    var message = JSON.parse(evt.data);
    if ('instances_list' in message) {
      showInstancesCard();
      $scope.instancesList = message['instances_list'];
    }
    if ('pages_list' in message) {
      showPagesCard();
      $scope.pagesList = message['pages_list'];
    }
    if ('commits_list' in message) {
      showCommitsCard();
      $scope.commitsList = message['commits_list'];
    }
    if ('entries_list' in message) {
      $scope.showEntries = true;
      $scope.entriesList = $scope.entriesList.concat(message['entries_list']);
    }
    $scope.$apply();
  }

  function showInstancesCard() {
    $scope.showPages = false;
    $scope.showCommits = false;
    $scope.showEntries = false;
    $scope.selectedInstIndex = -1;
  }

  function showPagesCard() {
    $scope.showPages = true;
    $scope.showCommits = false;
    $scope.showEntries = false;
    $scope.selectedPageIndex = -1;
  }

  function showCommitsCard() {
    $scope.showCommits = true;
    $scope.showEntries = false;
    $scope.selectedCommitIndex = -1;
  }

  $(document).ready(function() {
    connectWebSocket();
  });
});
