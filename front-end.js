const { ipcRenderer } = require('electron');
const renderPatches = require('./render-patches');
const ApiClient = require('./api-client');

const configElm = document.querySelector(".config");
const api = new ApiClient();

if (api.isLoggedIn()) {
  // console.log("creds", apiKey, apiEmail);
} else {
  showConfig();
}

var patches = [];

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

document.querySelector(".patch-browser").addEventListener("click", function(e) {
  if (e.target.getAttribute("href")) {
    e.preventDefault();
    ipcRenderer.send('show-in-finder', e.target.getAttribute("href"));
  }
});

document.querySelector(".header .icon").addEventListener("click", function(e){
  showConfig();
});

configElm.querySelector("form").addEventListener("submit", function(e) {
  e.preventDefault();
  const email = configElm.querySelector("#email").value;
  const token = configElm.querySelector("#token").value;
  if (email !== '' && token !== '') {
    api.logIn(email, token);
    hideConfig();
  } else {
    alert("Please enter an email and API token");
  }
});
function showConfig() {
  configElm.style.display = "block";
  configElm.querySelector("#email").value = api.email();
  configElm.querySelector("#token").value = api.token();
}
function hideConfig() { configElm.style.display = "none"; }

function parseUrl(url) {
  const a = document.createElement("a");
  a.href = url;
  return a;
}
