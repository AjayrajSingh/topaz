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
  $scope.headCommitsList = [];
  $scope.commitsObjDict = {};
  $scope.entriesList = [];
  $scope.showPages = false;
  $scope.showCommits = false;
  $scope.showEntries = false;
  $scope.selectedInstIndex = -1;
  $scope.selectedPageIndex = -1;
  $scope.selectedCommitId = null;

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

  $scope.getHeadCommitsList = function(index) {
    $scope.selectedPageIndex = index;
    _webSocket.send(JSON.stringify({'page_name': $scope.pagesList[index]}));
  };

  $scope.getEntriesList = function(commitId) {
    _webSocket.send(JSON.stringify({'commit_id': commitId}));
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
      $scope.headCommitsList = message['commits_list'];
      initCommitsGraph();
      drawCommitsGraph();
    }
    if ('commit_obj' in message) {
      updateCommitsGraph(message['commit_obj']);
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

  function initCommitsGraph() {
    $scope.commitsObjDict = {};
    for (var i = 0; i < $scope.headCommitsList.length; i++)
      getCommitObj($scope.headCommitsList[i]);
  }

  // return whether the commit is new
  function getCommitObj(commitId) {
    if (!(commitId in $scope.commitsObjDict)) {
      $scope.commitsObjDict[commitId] = {
        'index': Object.keys($scope.commitsObjDict).length,
        'timestamp': null,
        'generation': null
      };
      _webSocket.send(JSON.stringify({'commit_obj_id': commitId}));
      return true;
    }
    return false;
  }


  function drawCommitsGraph() {
    $scope.svg = d3.select('#commits-graph');
    $scope.svg.selectAll('*').remove();
    $scope.svg.attr('width', '100%');
    $scope.svgHeight = 500;
    $scope.svg.attr('height', $scope.svgHeight);
    $scope.color = function(commitId) {
      for (var i = 0; i < commitId.length; i++)
        if (commitId[i] != 0)
          return '#000000';
      return '#00AAC0';
    };

    $scope.nodes = [];
    for (var i = 0; i < $scope.headCommitsList.length; i++)
      $scope.nodes.push({
        index: $scope.commitsObjDict[$scope.headCommitsList[i]],
        id: $scope.headCommitsList[i]
      });


    $scope.links = [];

    var x = function(commitId) {
      var temp = $scope.commitsObjDict[commitId]['generation'];
      if (temp != null)
        return temp * 30;
      return 0;
    };

    $scope.simulation =
        d3.forceSimulation($scope.nodes)
            .force('y', d3.forceY(function(d) {
                            return x(d.id);
                          }).strength(2))
            .force('x', d3.forceX(0).strength(0.1))
            .force('charge', d3.forceManyBody().strength(-80).distanceMax(30))
            .force('link', d3.forceLink($scope.links).distance(30).strength(1))

            .on('tick', ticked);

    var g = $scope.svg.append('g').attr(
        'transform', 'translate(' + 10 + ',' + $scope.svgHeight / 2 + ')');
    $scope.link = g.append('g')
                      .attr('stroke', '#000')
                      .attr('stroke-width', 1.5)
                      .selectAll('.link');
    $scope.node = g.append('g')
                      .attr('stroke', '#fff')
                      .attr('stroke-width', 1.5)
                      .selectAll('.node');
    $scope.svg.call(d3.zoom().scaleExtent([1, 5]).on('zoom', function() {
      g.attr('transform', d3.event.transform)
    }));


    restart();
  }

  function restart() {
    // Apply the general update pattern to the nodes.
    $scope.node = $scope.node.data($scope.nodes);
    $scope.node.exit().remove();
    $scope.node = $scope.node.enter()
                      .append('circle')
                      .attr(
                          'fill',
                          function(d) {
                            return $scope.color(d.id);
                          })
                      .attr('r', 8)
                      .on('click',
                          function(d) {
                            $scope.getEntriesList(d.id);
                            $scope.selectedCommitId = d.id;
                          })
                      .merge($scope.node);

    // Apply the general update pattern to the links.
    $scope.link = $scope.link.data($scope.links, function(d) {
      return d.source.index + '-' + d.target.index;
    });
    $scope.link.exit().remove();
    $scope.link = $scope.link.enter().append('line').merge($scope.link);

    // Update and restart the simulation.
    $scope.simulation.nodes($scope.nodes);
    $scope.simulation.force('link').links($scope.links);
    $scope.simulation.alpha(1).restart();
  }

  function ticked() {
    $scope.node
        .attr(  // d.x, d.y are swapped for left-to-right orientation
            'cx',
            function(d) {
              return d.y;
            })
        .attr('cy', function(d) {
          return d.x;
        });

    $scope.link
        .attr(
            'x1',
            function(d) {
              return d.source.y;
            })
        .attr(
            'y1',
            function(d) {
              return d.source.x;
            })
        .attr(
            'x2',
            function(d) {
              return d.target.y;
            })
        .attr('y2', function(d) {
          return d.target.x;
        });
  }

  function updateCommitsGraph(commitObj) {
    var sourceIdx = $scope.commitsObjDict[commitObj[0]]['index'];
    for (var i = 0; i < commitObj[1].length; i++) {
      var isNewNode = getCommitObj(commitObj[1][i]);
      var targetIdx = $scope.commitsObjDict[commitObj[1][i]]['index'];
      if (isNewNode)
        $scope.nodes.push({index: targetIdx, id: commitObj[1][i]});
      $scope.links.push({source: sourceIdx, target: targetIdx});
    }
    $scope.commitsObjDict[commitObj[0]]['timestamp'] = commitObj[2];
    $scope.commitsObjDict[commitObj[0]]['generation'] = commitObj[3];
    restart();
  }


  $(document).ready(function() {
    connectWebSocket();
  });
});
