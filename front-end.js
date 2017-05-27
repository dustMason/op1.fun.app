const { ipcRenderer } = require('electron');
const ApiClient = require('./api-client');

const configElm = document.querySelector(".config");
const api = new ApiClient();

Vue.component('patch-list', {
  template: '#patch-list',
  props: ['patches', 'limit', 'name', 'id'],
  methods: {
    showInFinder: function(e) {
      if (e) {
        ipcRenderer.send('show-in-finder', e.target.getAttribute("href"));
      }
    },
  },
});

var categoryFilter = function(patches, category) {
  var filtered = patches.filter((p) => { return p.category === category });
  return filtered.sort(function(a, b) {
    var _a = (a.packDir || "").toLowerCase() + a.name.toLowerCase();
    var _b = (b.packDir || "").toLowerCase() + b.name.toLowerCase();
    if (_a < _b) { return -1 } else if (_a > _b) { return 1 }
    return 0;
  });
}

var app = new Vue({
  el: '#app',
  data: {
    patches: [],
    downloading: false,
    currentView: api.isLoggedIn() ? 'browser' : 'login'
  },
  methods: {
    goToView: function(e) { this.currentView = e; }
  },
  components: {
    
    //
    // LOGIN
    //
    login: {
      template: '#login',
      data: function() {
        return {
          email: api.email(),
          token: api.token()
        }
      },
      methods: {
        submit: function(e) {
          // console.log(this);
          // TODO simple validation on email/token
          api.logIn(this.email, this.token);
          this.$emit('go', 'browser');
        }
      }
    },
    
    //
    // BROWSER
    //
    browser: {
      template: '#browser',
      props: ['patches', 'downloading'],
      data: function() {
        return {
          limits: { drum: 42, synth: 100, sampler: 42 },
        }
      },
      computed: {
        drums: function() { return categoryFilter(this.patches, 'drum'); },
        synths: function() { return categoryFilter(this.patches, 'synth'); },
        samplers: function() { return categoryFilter(this.patches, 'sampler'); }
      }
    }
    
  }
  
});

ipcRenderer.on('render-patches', (event, patches) => {
  app.patches = patches;
});

ipcRenderer.on('start-download', (event, message) => {
  if (message['pack']) {
    app.downloading = "Downloading Pack: " + message.pack.name;
  } else if (message['patch']) {
    app.downloading = "Downloading Patch: " + message.patch.name;
  }
});

ipcRenderer.on('finish-download', (event, message) => {
  app.downloading = false;
});
