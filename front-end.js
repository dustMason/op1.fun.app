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
  var note;
  if (message['pack']) {
    note = "Downloading Pack: " + message.pack.name;
  } else if (message['patch']) {
    note = "Downloading Patch: " + message.patch.name;
  }
  showSpinner(note);
});

ipcRenderer.on('finish-download', (event, message) => {
  console.log('finish-download', message);
  hideSpinner();
});

document.querySelector(".patch-browser").addEventListener("click", function(e) {
  if (e.target.getAttribute("href")) {
    e.preventDefault();
    ipcRenderer.send('show-in-finder', e.target.getAttribute("href"));
  }
});

document.querySelector(".header .config-icon").addEventListener("click", function(e){
  showConfig();
});

configElm.querySelector("form").addEventListener("submit", function(e) {
  e.preventDefault();
  var email = configElm.querySelector("#email").value;
  var token = configElm.querySelector("#token").value;
  if (email !== '' && token !== '') {
    api.logIn(email, token);
    hideConfig();
  } else {
    alert("Please enter an email and API token");
  }
});
function showConfig() {
  configElm.style.display = "block";
  var email = api.email();
  if (email) { configElm.querySelector("#email").value = email; }
  var token = api.token();
  if (token) { configElm.querySelector("#token").value = token; }
}
function hideConfig() { configElm.style.display = "none"; }

const spinner = document.querySelector(".icon.spinner");
function showSpinner(note) {
  if (note) {
    spinner.querySelector("span").textContent = note;
  } else {
    spinner.querySelector("span").textContent = "Download";
  }
  spinner.style.display = "block";
}
function hideSpinner() { spinner.style.display = "none"; }
