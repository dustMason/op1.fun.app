const { menubar } = require('menubar');
const { autoUpdater, dialog, ipcMain, shell, Menu } = require('electron');
const { download } = require('electron-dl');
const chokidar = require('chokidar');
const drivelist = require('drivelist');
const Url = require('url');
const OP1Patch = require('./op1-patch');
const ApiClient = require('./api-client');
const api = new ApiClient();
const path = require('path');
const os = require('os');
const isDev = require('electron-is-dev');

if (!isDev) {
  const version = require('./package.json').version;
  const platform = os.platform() + "_" + os.arch();
  autoUpdater.setFeedURL('https://nuts.op1.fun/update/' + platform + '/' + version);
  autoUpdater.checkForUpdates();
  setInterval(() => { autoUpdater.checkForUpdates() }, 300000);

  autoUpdater.on('update-downloaded', (event, releaseNotes, releaseName) => {
    const dialogOpts = {
      type: 'info',
      buttons: ['Restart', 'Later'],
      title: 'Application Update',
      message: releaseName,
      detail: 'A new version of op1.fun.app has been downloaded. Restart the application to apply the update.'
    }

    dialog.showMessageBox(dialogOpts, (response) => {
      if (response === 0) autoUpdater.quitAndInstall();
    });
  });

  autoUpdater.on('error', message => {
    console.error('There was a problem updating the application');
    console.error(message);
  });
}

var email,
    token,
    watcher,
    urlToOpen,
    mountpoint,
    patches = [],
    mounted = false,
    settingUpWatcher = false;

// mountpoint = "/Users/jordan/Documents/OP-1/fakeop1";

const mb = menubar({
  browserWindow: {
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    },
    width: 600
  },
  preloadWindow: true,
  icon: path.join(__dirname, 'icon.png')
});

mb.on('ready', function ready() {
  ensureConnected().then(function (message) {
    mb.showWindow();
  }, function (reason) {
    mb.showWindow();
  });
});

mb.app.on('open-url', function (e, urlStr) {
  e.preventDefault();
  if (ensureLoggedIn()) {
    ensureConnected().then(function () {
      var { id, path, type } = parseUrl(urlStr);
      if (type === 'packs' && id) {
        api.getPack(path, id, loadPack);
      } else if (type === 'patches' && id) {
        api.getPatch(path, id, loadPatch);
      }
    });
  };
});

// mb.on('after-create-window', function () {
//   mb.window.openDevTools();
// });

mb.on('after-show', function show() {
  if (ensureLoggedIn()) {
    ensureConnected().catch(function (reason) {
      // noop
    });
  };
});

ipcMain.on('show-popup-menu', (event, args) => {
  let menu;
  if (args.view === 'login') {
    menu = Menu.buildFromTemplate([
      { role: 'quit' }
    ]);
  } else {
    menu = Menu.buildFromTemplate([
      { label: 'Account Settings', click: () => {
        mb.window.webContents.send('go-to-view', 'login');
      }},
      { type: 'separator' },
      { role: 'quit' }
    ]);
  }
  
  menu.popup(mb.window);
});

ipcMain.on('show-in-finder', (event, arg) => {
  shell.showItemInFolder(mountpoint + arg);
});

ipcMain.on('mount-op1', (event, arg) => {
  ensureConnected().catch(function (reason) {
    // noop
  });
});

ipcMain.on('show-config-menu', (event, arg) => {
  popupMenu.popup();
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
    result = result.then(function () {
      mb.window.webContents.send('finish-download', { patch: patch });
    });
  }
  return result;
}

function loadPack(pack) {
  mb.window.webContents.send('start-download', { pack: pack });
  var result = Promise.resolve();
  pack.patches.forEach(function (patch) {
    result = result.then(() => loadPatch(patch, pack.id));
  });
  result = result.then(function () {
    mb.window.webContents.send('finish-download', { pack: pack });
  })
  return result;
}

function parseUrl(urlStr) {
  var parsed = Url.parse(urlStr);
  var path = parsed.pathname
  while (path.charAt(0) === "/") { path = path.slice(1); }
  var parts = path.split("/");
  return { type: parts[2], id: parts[3], path: path };
}

function ensureLoggedIn() {
  if (!api.isLoggedIn()) {
    mb.window.webContents.send('show-login', {
      message: 'Please login to download packs and patches.'
    });
    return false;
  }
  return true;
}

function ensureConnected() {
  if (mounted) {
    mb.window.webContents.send('op1-connected', true);
    return Promise.resolve(true);
  } else if (!settingUpWatcher) {
    settingUpWatcher = true;
    return watchOP1().then(function () {
      mb.window.webContents.send('op1-connected', true);
      settingUpWatcher = false;
    }, function (error) {
      mb.window.webContents.send('op1-connected', false);
      settingUpWatcher = false;
      return Promise.reject();
    });
  } else {
    return Promise.reject();
  }
}

async function watchOP1() {
  if (watcher) {
    watcher.close();
  }

  if (patches.length > 0) {
    patches = [];
  }

  try {
    const drives = await drivelist.list();

    for (let i = 0; i < drives.length; i++) {
      if (drives[i].description.indexOf("OP-1") > -1) {
        const m = drives[i].mountpoints[0];
        if (m) {
          mountpoint = m.path;
          break;
        }
      }
    }

    if (!mountpoint) {
      mounted = false;
      throw new Error("OP-1 not found");
    } else {
      mounted = true;
    }

    watcher = chokidar.watch(mountpoint, {
      ignored: /(^|[\/\\])\../,
      awaitWriteFinish: true
    }).on('all', (event, path) => {
      if (mountpoint) {
        const relPath = path.slice(mountpoint.length);
        const parts = relPath.split("/");
        if (
          // ignore album, tape and user preset patches
          ((parts[1] === "synth") || (parts[1] === "drum")) && parts[2] != "user"
        ) {
          if (event === 'add') {
            try {
              const patch = new OP1Patch({ path: path, relPath: relPath });
              if (patch.metadata) {
                patches.push(patch);
                mb.window.webContents.send('render-patches', patches);
              }
            } catch (e) {
              console.log(e);
            }
          } else if (event === 'unlink') {
            patches = patches.filter(function (p) { return p.relPath !== relPath });
            mb.window.webContents.send('render-patches', patches);
          }
        } else {
          // console.log(event, path);
        }
      }
    }).on('raw', function (event, path, details) {
      if (
        (details.event === 'root-changed') ||
        (details.event === 'deleted' && path === mountpoint)
      ) {
        mountpoint = null;
        mounted = false; // treat this as a disconnect
      }
    });

    return watcher;
  } catch (error) {
    return Promise.reject(error);
  }
}
