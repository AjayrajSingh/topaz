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

  $(document).ready(function(){
    getInstancesList();
  });
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

function getInstancesList() {
  $.get( _ReqUrl + "/instances_list",
        function(data, status){
          var instancesList = JSON.parse(JSON.stringify(data));
          $("#number-of-ledger-instances").append(instancesList.length);
          for(var i = 0; i < instancesList.length; i++) {
            var methodElem = $("<li></li>")
            .addClass('mdc-list-item')
            .text(instancesList[i])
            .attr('id', instancesList[i])
            .click(getPagesList);

            $("#ledger-instances-list").append(methodElem);
          }

        });
}

function getPagesList() {
  var elemName = $(event.target).text();
  $.get( _ReqUrl + "/pages_list",
    { instance: elemName },
    function(data, status){
      var pagesList = data;
      stringsList = bytesToStrings(pagesList);

      $("#number-of-ledger-pages").text("Number of "+ elemName + " pages: " +
                                        (stringsList.length).toString());
      $("#ledger-pages-list").empty();
      for(i = 0; i< stringsList.length; i++) {
        var methodElem = $("<li></li>")
        .addClass('mdc-list-item')
        .text(stringsList[i]);

        $("#ledger-pages-list").append(methodElem);
      }
      return;
    }).fail( function() { console.log("The GET request didn't work! You need to\
    check that the server is working properly."); } );
  return false;
}

function bytesToStrings(bytesList) {
  var stringsList = new Array();
  for(var i = 0; i < bytesList.length; i++) {
    var str = "";
    for(var j = 0; j < bytesList[i].length; j++) {
      if((bytesList[i][j] >= 0 && bytesList[i][j] <= 31)
          || bytesList[i][j] >= 127) {
        str = bytesToHex(bytesList[i]);
        break;
      }
      str += String.fromCharCode(bytesList[i][j]);
    }
    stringsList.push(str);
  }
  return stringsList;
}


function bytesToHex(bytes) {
  var hexString = '0x';
  for(var i = 0; i < bytes.length; i++) {
    hexString += bytes[i].toString(16);
  }
  return hexString;
}
