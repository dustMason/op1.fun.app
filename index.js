const menubar = require('menubar');
const {protocol, ipcMain, shell} = require('electron');
const {download} = require('electron-dl');
const chokidar = require('chokidar');
const drivelist = require('drivelist');
const Url = require('url');
const OP1Patch = require('./op1-patch');
const ApiClient = require('./api-client');

// for dev
// require('electron-context-menu')();

// TODO
// on 'after-show' and 'open-url' check to see if OP1 is mounted and being watched.
// if not, try to and error out to user if that fails

var email, token, watcher, urlToOpen, mountpoint, patches = [];
// mountpoint = "/Users/jordan/Documents/OP-1/fakeop1";

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
  if (!api.isLoggedIn()) {
    alert("Please sign in.");
    showConfig();
    return;
  }
  var { id, path, type } = parseUrl(urlStr);
  if (type === 'packs' && id) {
    api.getPack(path, id, loadPack);
  } else if (type === 'patches' && id) {
    api.getPatch(path, id, loadPatch);
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

function loadPatch(patch, packDir) {
  mb.showWindow();
  var dir = [mountpoint];
  if (patch['patch-type'] === 'drum') {
    dir.push('drum');
  } else {
    dir.push('synth');
  }
  if (packDir) {
    dir.push(packDir);
  } else {
    mb.window.webContents.send('start-download', { patch: patch });
  }
  result = download(mb.window, patch.links.file, { directory: dir.join("/") });
  if (!packDir) {
    result = result.then(function() {
      mb.window.webContents.send('finish-download', { patch: patch });
    });
  }
	return result
  // .then(dl => console.log(dl.getSavePath()))
	// .catch(console.error);
}

function loadPack(pack) {
  console.log("will load pack", pack);
  mb.window.webContents.send('start-download', { pack: pack });
  var result = Promise.resolve();
  pack.patches.forEach(function(patch) {
    result = result.then(() => loadPatch(patch, pack.id));
  });
  result = result.then(function() {
    mb.window.webContents.send('finish-download', { pack: pack });
  })
  return result;
}

function patchCounts() {
  var counts = { synth: 0, drum: 0, sampler: 0 }
  patches.forEach(function(p) { counts[p.category]++; });
  return counts;
}

function parseUrl(urlStr) {
  var parsed = Url.parse(urlStr);
  var path = parsed.pathname
  while (path.charAt(0) === "/") { path = path.slice(1); }
  var parts = path.split("/");
  return { type: parts[2], id: parts[3], path: path };
}

function watchOP1() {
  if (watcher) {
    watcher.close();
  }
  
  drivelist.list((error, drives) => {
    if (error) { throw error; }
    
    // TODO find the mountpoint belonging to the OP-1 and pass it to chokidar
    for (var i = 0; i < drives.length; i++) {
      // console.log(drives[i]);
      if (drives[i].description.indexOf("OP-1") > -1) {
        mountpoint = drives[i].mountpoints[0].path;
        break;
      }
    }
    
    if (!mountpoint) {
      throw(new Error("OP-1 not found"));
    }
    
    watcher = chokidar.watch(mountpoint, {
      ignored: /(^|[\/\\])\../,
      awaitWriteFinish: true
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
              patches.push(patch);
              mb.window.webContents.send('render-patches', patches);
            }
          } catch(e) {
            console.log(e);
          }
        } else if (event === 'unlink') {
          patches = patches.filter(function(p) { return p.relPath !== relPath });
          mb.window.webContents.send('render-patches', patches);
        }
      } else {
        // console.log(event, path);
      }
    });
  });
}
