const lists = {
  synth: document.querySelector("#synth ul"),
  drum: document.querySelector("#drum ul"),
  sampler: document.querySelector("#sampler ul"),
}
const usages = {
  synth: document.querySelector("#synth .usage"),
  drum: document.querySelector("#drum .usage"),
  sampler: document.querySelector("#sampler .usage"),
}
const limits = { synth: 100, drum: 42, sampler: 42 };
var counts = { synth: 0, drum: 0, sampler: 0 }

function patchListItem(patch) {
  return listItem(patch.name, "patch", patch.relPath);
}

const folderIcon = '<svg viewBox="0 0 32 32" style="fill:currentcolor"><path d="M0 4 L0 28 L32 28 L32 8 L16 8 L12 4 z"></path></svg>'

function listItem(text, className, href, icon) {
  var li = document.createElement("li");
  var a = document.createElement("a");
  if (className) { a.classList.add(className); }
  if (href) { a.setAttribute("href", href); }
  a.textContent = text;
  if (icon) {
    var img = document.createElement("svg");
    a.prepend(img);
    img.outerHTML = icon;
  }
  li.appendChild(a);
  return li;
}

module.exports = function(patches) {
  for (var cat in counts) {
    lists[cat].innerHTML = "";
    counts[cat] = 0;
  }
  var packs = {};
  for (var i = 0; i < patches.length; i++) {
    var patch = patches[i];
    var li = patchListItem(patch);
    if (patch.packDir) {
      if (!packs.hasOwnProperty(patch.packDir)) {
        var titleLi = listItem(patch.packName, "pack", patch.packDir, folderIcon);
        lists[patch.category].appendChild(titleLi);
        var ul = document.createElement("ul");
        packs[patch.packDir] = ul;
        lists[patch.category].appendChild(ul);
      } 
      packs[patch.packDir].appendChild(li);
    } else {
      lists[patch.category].appendChild(li);
    }
    counts[patch.category]++;
  }
  for (var cat in counts) {
    usages[cat].innerHTML = counts[cat] + " of " + limits[cat];
  }
}
