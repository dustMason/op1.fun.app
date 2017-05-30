const JsonApiDataStore = require('jsonapi-datastore').Store;
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
  
  logIn(email, password, callback) {
    var me = this;
    this.config.set('email', email);
    var req = https.request({
      method: 'POST',
      host: 'api.op1.fun',
      path: '/v1/api_token',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    }, function(res) {
      var body = '';
      res.on('data', function(d) { body += d; });
      res.on('end', function() {
        var res = JSON.parse(body);
        if (res.api_token) {
          me.config.set('token', res.api_token);
        }
        callback(res);
      });
    });
    req.write(JSON.stringify({ email: email, password: password }));
    req.end();
  }
  
  logOut(callback) {
    this.config.set('email', null);
    this.config.set('token', null);
    callback();
  }
  
  isLoggedIn() {
    return (this.email() && this.token());
  }
  
  getPack(path, id, callback) {
    var me = this;
    this._request(path, function() {
      var pack = me.store.find("packs", id);
      callback(pack);
    })
  }
  
  getPatch(path, id, callback) {
    var me = this;
    this._request(path, function() {
      var patch = me.store.find("patches", id);
      callback(patch);
    })
  }
  
  _request(path, callback) {
    var me = this;
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
        me.store.sync(JSON.parse(body));
        callback();
      });
    });
  }
  
}

module.exports = ApiClient;
