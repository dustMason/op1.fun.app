const { ipcRenderer } = require('electron');
const ApiClient = require('./api-client');
const groupBy = require('./lib/group-by');

const configElm = document.querySelector(".config");
const api = new ApiClient();

var categoryFilter = function(patches, category) {
  var filtered = patches.filter((p) => { return p.category === category });
  return filtered.sort(function(a, b) {
    // "/000" makes root level patches sort to the top
    var _a = (a.packDir || "/000") + a.name.toLowerCase();
    var _b = (b.packDir || "/000") + b.name.toLowerCase();
    if (_a < _b) { return -1 } else if (_a > _b) { return 1 }
    return 0;
  });
}

var app = new Vue({
  el: '#app',
  data: {
    patches: [],
    downloading: false,
    currentView: api.isLoggedIn() ? 'browser' : 'login',
    currentListId: 'synth'
  },
  methods: {
    goToView: function(e) { this.currentView = e },
    showList: function(e) { this.currentListId = e },
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
      props: ['patches', 'downloading', 'currentListId'],
      computed: {
        filteredPatches: function() {
          return categoryFilter(this.patches, this.currentListId);
        },
      },
      components: {
        sideNav: {
          template: '#side-nav',
          props: ['patches', 'currentListId'],
          data: function() {
            return {
              limits: { drum: 42, synth: 100, sampler: 42 },
            }
          },
          computed: {
            navItems: function() {
              var sub = (cat) => {
                return categoryFilter(this.patches, cat).length + " of " + this.limits[cat];
              }
              return [
                { id: 'synth', title: 'Synth', subtitle: sub('synth') },
                { id: 'drum', title: 'Drum', subtitle: sub('drum') },
                { id: 'sampler', title: 'Sampler', subtitle: sub('sampler') },
                { id: 'backups', title: 'Backups', subtitle: 'ok' },
              ]
            }
          }
        },
        contentArea: {
          template: "<component :is='currentComponent' :patches='patches' :id='id'></component>",
          props: ['currentListId', 'patches', 'id'],
          computed: {
            currentComponent: function() {
              return (this.currentListId === 'backups') ? 'backups' : 'patch-list';
            }
          },
          components: {
            
            patchList: {
              template: '#patch-list',
              props: ['patches', 'id'],
              computed: {
                packs: function() { return groupBy(this.patches, 'packName') }
              },
              methods: {
                showInFinder: function(e) {
                  if (e) {
                    ipcRenderer.send('show-in-finder', e.target.getAttribute("href"));
                  }
                },
              },
            },
            backups: {
              template: '#backups'
            }
            
          }
        }
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
