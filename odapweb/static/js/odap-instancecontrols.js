/*!
**
** ODAP Manager Web Portal Instance Control Functions
**
*/

/**
* The InstanceCmd function expects to have an element called warning-box it can talk
* to and set error messages to. In general, it'll also drop the error json into
* the Javascript console, but users tend to not look there.
*/
function instanceCmd(id, verb) {
  $.ajax({
    url:"/ajax/instance/" + id + "/" + verb , 
    type: "GET",
    dataType: 'json',
    success: function(json) {
      console.log(json);
      var wbox = document.getElementById("warning-box");
      $(wbox).prop("hidden", true); // hide it if it was visible before
      if (json.status != 'ok') {
        
        console.log("action failed.")
        console.log("warning box contains '"+ wbox.textContent+"'");
        
        /*
        //Populates the message with the actual error
        msg = "Error:<br>Action:" + json.action + "<br>";
        if( json.exception) {
          msg += json.exception
        }
        */
        //Populates the message with something friendly and useless
        msg = "<span class=\"glyphicon glyphicon-warning-sign\"></span> We're sorry, but an error has occurred. our flying code monkeys have been notified :)<br>Please try again in a few minutes";
        $(wbox).html(msg);
        $(wbox).prop("hidden", false);

      } else {
        $.ajax({
          url: "/ajax/user-instances",
          type: "GET",
          dataType: "json",
          success: location.reload()
          });
      }
    }
  })
}

function startInst(id) {
  console.log("start instance " + id);
  //var confirm = window.confirm("Really start instance?");
  //if (confirm == true) {
  instanceCmd(id, "start");
  //}
}

function stopInst(id) {
  console.log("stop instance " + id);
  var confirm = window.confirm("Really stop instance?");
  if (confirm == true) {
    instanceCmd(id, "stop");
  }
}

function rbInst(id) { 
  console.log("reboot instance " + id);
  var confirm = window.confirm("Really reboot instance?");
  if (confirm == true) {
    instanceCmd(id, "restart");
  }
}

function termInst(id) { 
  console.log("terminate instance " + id);
  var confirm = window.confirm("This will terminate all instances and volumes attached to the stack. This cannot be undone.");
  if (confirm == true) {
    instanceCmd(id, "terminate");
  }
}

// function to handle appgate warning per ODAP-87
// no longer used per ODAP-110

function instanceLink(ipaddr) {
	$( "#dialog-confirm" ).data('ipaddr', ipaddr).dialog({
	      resizable: false,
	      height: "auto",
	      width: 400,
	      modal: true,
	      buttons: {
	        "Connect to Instance": function(ipaddr) {
            var ip = $(this).data('ipaddr');
	          location.replace( "https://" + ip + "/" );

	        },
	        Cancel: function() {
	          $( this ).dialog( "close" );
	        }
	      }
	    });
}
