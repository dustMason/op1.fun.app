const menubar = require('menubar');
const {protocol, ipcMain, shell} = require('electron');
const chokidar = require('chokidar');
const drivelist = require('drivelist');
const OP1Patch = require('./op1-patch');
// require('electron-context-menu')();

var email, token;

const mb = menubar({
  preloadWindow: true,
  width: 600
});

var urlToOpen, mountpoint;
mountpoint = "/Users/jordan/Documents/OP-1/fakeop1";

mb.on('ready', function ready() {
  watchOP1();
});

mb.app.on('open-url', function(e, url) {
  e.preventDefault();
  if (!mb.showWindow) {
    urlToOpen = url;
  } else {
    mb.showWindow();
    mb.window.webContents.send('url', url);
  }
});

mb.on('after-create-window', function() {
  mb.window.openDevTools();
});

mb.on('after-show', function show() {
  if (urlToOpen) {
    mb.window.webContents.send('url', urlToOpen);
    urlToOpen = null;
  }
  if (email && token) {
    console.log("got creds", email, token);
    
  }
});

ipcMain.on('show-in-finder', (event, arg) => {
  console.log(mountpoint + arg);
  shell.showItemInFolder(mountpoint + arg);
});

function watchOP1() {
  drivelist.list((error, drives) => {
    if (error) { throw error; }
    
    // TODO find the mountpoint belonging to the OP-1 and pass it to chokidar
    // for (var i = 0; i < drives.length; i++) {
    //   console.log(drives[i].mountpoints);
    // }
    
    chokidar.watch(mountpoint, {
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
