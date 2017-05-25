const menubar = require('menubar');
const {protocol, ipcMain, shell} = require('electron');
const chokidar = require('chokidar');
const drivelist = require('drivelist');
// const usbDetect = require('usb-detection');
const Url = require('url');
const OP1Patch = require('./op1-patch');
const ApiClient = require('./api-client');
// require('electron-context-menu')();

// TODO detect when OP-1 is connected and run watchOP1()
// TODO stop listening when app closes
// usbDetect.on('add', function(device) {
//   console.log('add', device);
// });
// usbDetect.on('add:vid', function(device) { console.log('add', device); });
// usbDetect.on('add:vid:pid', function(device) { console.log('add', device); });

var email, token, watcher, urlToOpen, mountpoint;
mountpoint = "/Users/jordan/Documents/OP-1/fakeop1";

const api = new ApiClient();

const mb = menubar({
  preloadWindow: true,
  width: 600
});

mb.on('ready', function ready() {
  watchOP1();
});

mb.app.on('open-url', function(e, urlStr) {
  e.preventDefault();
  console.log("got urlStr", e, urlStr);
  // mb.window.webContents.send('urlStr', urlStr);
  if (!api.isLoggedIn()) {
    alert("Please sign in.");
    showConfig();
    return;
  }
    
  var parsed = Url.parse(urlStr);
  var path = parsed.pathname
  while (path.charAt(0) === "/") { path = path.slice(1); }
  var parts = path.split("/");
  var type = parts[2];
  var id = parts[3];
  console.log(path, parts);
  
  if (type === 'packs' && id) {
    api.getPack(path, id, function(pack) { loadPack(pack); });
  } else if (type === 'patches' && id) {
    api.getPatch(path, id, function(patch) { loadPatch(patch); });
  } else {
    console.log("Don't know how to handle URL", message);
  }
  
});

mb.on('after-create-window', function() {
  mb.window.openDevTools();
});

mb.on('after-show', function show() { });

ipcMain.on('show-in-finder', (event, arg) => {
  console.log(mountpoint + arg);
  shell.showItemInFolder(mountpoint + arg);
});

function loadPatch(patch) {
  // check to see if there is enough space on device
  // if so, download the patch and save to disk
  // if no, warn user
}

function loadPack(pack) {
  // check to see if there is enough space on device
  // if so, download all patches and save to disk
  // if no, warn user
}

function watchOP1() {
  
  if (watcher) {
    watcher.close();
  }
  
  drivelist.list((error, drives) => {
    if (error) { throw error; }
    
    // TODO find the mountpoint belonging to the OP-1 and pass it to chokidar
    // for (var i = 0; i < drives.length; i++) {
    //   console.log(drives[i].mountpoints);
    // }
    
    watcher = chokidar.watch(mountpoint, {
      ignored: /(^|[\/\\])\../
    }).on('all', (event, path) => {
      var relPath = path.slice(mountpoint.length);
      var parts = relPath.split("/");
      if (
        // ignore album, tape and user preset patches
        ((parts[1] === "synth") || (parts[1] === "drum")) && parts[2] != "user"
      ) {
        if (event === 'add') {
          try {
            const patch = new OP1Patch({path: path, relPath: relPath});
            if (patch.metadata) {
              mb.window.webContents.send('add-patch', { patch: patch });
            }
          } catch(e) {
            console.log(e);
          }
        } else if (event === 'unlink') {
          mb.window.webContents.send('remove-patch', { relPath: relPath });
        }
      } else {
        // console.log(event, path);
      }
    });
  });
}
