const JsonApiDataStore = require('jsonapi-datastore').JsonApiDataStore;
const Config = require('electron-config');
const https = require('https');

class ApiClient {
  constructor() {
    this.config = new Config();
    this.store = new JsonApiDataStore();
  }
  
  token() {
    return this.config.get('token');
  }
  
  email() {
    return this.config.get('email');
  }
  
  logIn(email, token) {
    // TODO this should accept a password instead and make the call to get token
    this.config.set('email', email);
    this.config.set('token', token);
  }
  
  isLoggedIn() {
    return (this.email() && this.token());
  }
  
  getPack(path, id, callback) {
    this._request(path, function() {
      var pack = this.store.find("packs", id);
      callback(pack);
    })
  }
  
  getPatch(path, id, callback) {
    this._request(path, function() {
      var patch = this.store.find("patches", id);
      callback(patch);
    })
  }
  
  _request(path, callback) {
    return https.get({
      host: 'api.op1.fun',
      path: '/v1/' + path,
      headers: {
        'X-User-Email': this.email(),
        'X-User-Token': this.token()
      }
    }, function(res) {
      var body = '';
      res.on('data', function(d) { body += d; });
      res.on('end', function() {
        this.store.syncWithMeta(JSON.parse(body));
        callback();
      });
    });
  }
  
}

module.exports = ApiClient;
