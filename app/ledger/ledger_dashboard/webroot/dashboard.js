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
    instancesObjects = new Array();
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

class Instance {
    constructor(encodedString) {
      this.encodedName = encodedString;
      this.decodedName = "";
    }
    addInList(listId) {
      this.decodedName = bytesToString(this.encodedName);
      var methodElem = $("<li></li>")
      .addClass('mdc-list-item')
      .text(this.decodedName)
      .attr('id', this.decodedName)
      .click($.proxy(this.getPagesList, this));

      $(listId).append(methodElem);
    }
    getPagesList() {
      var clickedName = this.decodedName;
      $.get( _ReqUrl + "/pages_list",
        { instance: JSON.stringify(this.encodedName) },
        function(pagesList, status) {
          var stringsList = new Array();
          for(var i = 0; i < pagesList.length; i++)
            stringsList.push(bytesToString(pagesList[i]));

          $("#number-of-ledger-pages").text("Number of "+
                                            clickedName + " pages: " +
                                            (stringsList.length).toString());
          $("#ledger-pages-list").empty();
          for(var i = 0; i < stringsList.length; i++) {
            var methodElem = $("<li></li>")
            .addClass('mdc-list-item')
            .text(stringsList[i]);

            $("#ledger-pages-list").append(methodElem);
          }
          return;
        }).fail( function() { console.log("The GET request didn't work! You \
        need to check that the server is working properly."); } );
      return false;
    }
}

function getInstancesList() {
  $.get( _ReqUrl + "/instances_list", function(instancesList, status){
        for(var i = 0; i < instancesList.length; i++) {
          newInstance = new Instance(instancesList[i]);
          newInstance.addInList("#ledger-instances-list");
          instancesObjects.push(newInstance);
        }
        $("#number-of-ledger-instances").append(instancesObjects.length);
      });
}

function bytesToString(bytesList) {
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
}

function bytesToHex(bytes) {
  var hexString = '0x';
  for(var i = 0; i < bytes.length; i++) {
    hexString += bytes[i].toString(16);
  }
  return hexString;
}
