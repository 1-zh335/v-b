// 番茄章节正文解密脚本（AnalyzerRule content.script）
// 输入：source = reader 页 HTML
// 步骤：取 __INITIAL_STATE__ JSON -> reader.chapterData.content(HTML) -> 去标签 -> PUA 字体解密
var s = String(source);
var idx = s.indexOf("window.__INITIAL_STATE__=");
var text = "";
if (idx >= 0) {
  var start = s.indexOf("{", idx);
  var depth = 0;
  var j = start;
  var inStr = false;
  var esc = false;
  while (j < s.length) {
    var ch = s.charAt(j);
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (ch === "\\") {
        esc = true;
      } else if (ch === '"') {
        inStr = false;
      }
    } else {
      if (ch === '"') {
        inStr = true;
      } else if (ch === "{") {
        depth++;
      } else if (ch === "}") {
        depth--;
        if (depth === 0) {
          break;
        }
      }
    }
    j++;
  }
  try {
    var obj = JSON.parse(s.substring(start, j + 1));
    if (obj && obj.reader && obj.reader.chapterData && obj.reader.chapterData.content) {
      text = String(obj.reader.chapterData.content);
    }
  } catch (e) {
    text = "";
  }
}
text = text.replace(/<\/p>/gi, "\n").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]+>/g, "");
text = text.replace(/&nbsp;/g, " ");
text = text.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");

var T0 = __CHARSET0__;
var T1 = __CHARSET1__;
var LO = 58344;
var HI = 58716;

function decodePua(mode, src) {
  var table = mode === 0 ? T0 : T1;
  var base = mode === 0 ? 58344 : 58345;
  var top = mode === 0 ? 58715 : 58716;
  var out = [];
  for (var k = 0; k < src.length; k++) {
    var code = src.charCodeAt(k);
    if (code >= base && code <= top) {
      var rep = table[code - base];
      if (rep !== undefined && rep !== null && rep !== "?") {
        out.push(rep);
      } else {
        out.push(src.charAt(k));
      }
    } else {
      out.push(src.charAt(k));
    }
  }
  var joined = out.join("");
  var left = 0;
  for (var m = 0; m < joined.length; m++) {
    var cc = joined.charCodeAt(m);
    if (cc >= LO && cc <= HI) {
      left++;
    }
  }
  return [joined, left];
}

var d0 = decodePua(0, text);
var d1 = decodePua(1, text);
result = d0[1] <= d1[1] ? d0[0] : d1[0];
