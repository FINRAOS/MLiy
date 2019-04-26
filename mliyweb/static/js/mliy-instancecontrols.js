/*
Copyright 2017 MLiy Contributors
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/*!
**
** MLIY Manager Web Portal Instance Control Functions
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
        msg = "<span class=\"glyphicon glyphicon-warning-sign\"></span> We're sorry, but an error has occurred doing: <br>" + verb;
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

function archInst(id) {
  console.log("archive instance " + id);
  var confirm = window.confirm("This will archive the instance. It will no longer appear in the UI.");
  if (confirm == true) {
    instanceCmd(id, "archive");
  }
}
