const fs = require('fs');
const wordAlign = function(v) { return v + v % 2; }

class OP1Patch {
  constructor(options) {
    this.path = options.path;
    this.relPath = options.relPath;
    this._pathParts = this.relPath.split("/");
    this.name = this._pathParts[this._pathParts.length-1];
    this.metadata = null;
    this.category = null;
    this.packName = null;
    this.packDir = null;
    this._parse();
    this._setPackName();
    this._setPackDir();
  }
  
  _parse() {
    var bytes = fs.readFileSync(this.path);
    if (String.fromCharCode.apply(null, bytes.subarray(0, 4)) !== 'FORM') {
      throw(new Error("FORM header not found"));
    }
    var dv = new DataView(bytes.buffer, 0, bytes.byteLength);
    var length = dv.getUint32(4, false);
    if (bytes.byteLength < 8+length) {
      throw(new Error("invalid data length"));
    }
    if (String.fromCharCode.apply(null, bytes.subarray(8, 12)) !== 'AIFC') {
      throw(new Error("AIFC header not found"));
    }
    for (var pos = 12; pos < length; pos += 8 + wordAlign(dv.getUint32(pos + 4, false))) {
      var chunkName = String.fromCharCode.apply(null, bytes.subarray(pos, pos + 4));
      if (chunkName === 'APPL') {
        var signature = String.fromCharCode.apply(null, bytes.subarray(pos+8, pos+12));
        var appl = String.fromCharCode.apply(null, bytes.subarray(
          pos + 12,
          pos + 8 + dv.getUint32(pos + 4, false)
        ));
        if (signature === 'op-1') {
          this.metadata = JSON.parse(appl);
          this._setCategory();
        }
        break;
      }
    }
  }
  
  _setCategory() {
    if (this.metadata.type === "drum") {
      this.category = "drum";
    } else if (this.metadata.type === "sampler") {
      this.category = "sampler";
    } else if (this.metadata.type) {
      this.category = "synth";
    }
  }
  
  _setPackName() {
    if (this._pathParts.length > 3) {
      this.packName = this._pathParts.slice(2,this._pathParts.length-1).join("/");
    }
  }
  
  _setPackDir() {
    if (this._pathParts.length > 3) {
      this.packDir = this._pathParts.slice(0,this._pathParts.length-1).join("/");
    }
  }
}

module.exports = OP1Patch;
