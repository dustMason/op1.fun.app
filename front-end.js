const JsonApiDataStore = require('jsonapi-datastore').JsonApiDataStore;
const { ipcRenderer } = require('electron');
const Config = require('electron-config');
const renderPatches = require('./render-patches');

const config = new Config();
const apiKey = config.get('apitoken');
const apiEmail = config.get('email');

const configElm = document.querySelector(".config");

function loggedIn() { return (apiEmail && apiKey); }

if (loggedIn()) {
  console.log("creds", apiKey, apiEmail);
} else {
  showConfig();
}

var store = new JsonApiDataStore();
var patches = [];

ipcRenderer.on('url', (event, message) => {
  if (!loggedIn()) {
    alert("Please sign in.");
    showConfig();
    return;
  }
  
  console.log("got event", event, message);
  var parsed = parseUrl(message);
  var path = parsed.pathname
  while (path.charAt(0) === "/") { path = path.slice(1); }
  var parts = path.split("/");
  var type = parts[2];
  var id = parts[3];
  console.log(path, parts);
  apiRequest(path, function(data) {
    console.log("got from api:", data);
    if (type === 'packs' && id) {
      store.syncWithMeta(data);
      var pack = store.find("packs", id);
      loadPack(pack);
    } else if (type === 'patches' && id) {
      store.syncWithMeta(data);
      var patch = store.find("patches", id);
      loadPatch(patch);
    } else {
      console.log("Don't know how to handle URL", message);
    }
  });
});

ipcRenderer.on('add-patch', (event, message) => {
  // console.log('add-patch', event, message);
  patches.push(message.patch);
  // TODO sort patches?
  renderPatches(patches);
});

ipcRenderer.on('remove-patch', (event, message) => {
  // console.log('remove-patch', event, message);
  patches = patches.filter(function(p) { return p.relPath !== message.relPath });
  renderPatches(patches);
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

function apiRequest(path, callback) {
  var req = new XMLHttpRequest();
  req.addEventListener("load", function() {
    callback(JSON.parse(this.responseText));
  });
  req.open("GET", "https://api.op1.fun/v1/" + path);
  req.setRequestHeader('X-User-Email', apiEmail);
  req.setRequestHeader('X-User-Token', apiKey);
  req.send();
}

document.querySelector(".patch-browser").addEventListener("click", function(e) {
  if (e.target.getAttribute("href")) {
    e.preventDefault();
    ipcRenderer.send('show-in-finder', e.target.getAttribute("href"));
  }
});

configElm.querySelector("form").addEventListener("submit", function(e) {
  e.preventDefault();
  const email = configElm.querySelector("#email").value;
  const token = configElm.querySelector("#apitoken").value;
  if (email !== '' && token !== '') {
    config.set('email', email);
    config.set('apitoken', token);
    hideConfig();
  } else {
    alert("Please enter an email and API token");
  }
});
function showConfig() { configElm.style.display = "block"; }
function hideConfig() { configElm.style.display = "none"; }

function parseUrl(url) {
  const a = document.createElement("a");
  a.href = url;
  return a;
}
