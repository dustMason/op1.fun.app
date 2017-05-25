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

ipcRenderer.on('render-patches', (event, patches) => {
  renderPatches(patches);
});

ipcRenderer.on('start-download', (event, message) => {
  console.log('start-download', message);
});

ipcRenderer.on('finish-download', (event, message) => {
  console.log('finish-download', message);
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
