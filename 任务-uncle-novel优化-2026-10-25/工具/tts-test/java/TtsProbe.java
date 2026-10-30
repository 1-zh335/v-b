import com.unclezs.novel.analyzer.request.Http;
import com.unclezs.novel.analyzer.request.RequestParams;
import com.unclezs.novel.app.main.model.config.TTSConfig;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * 复现 Uncle小说 5.0.44 的真实 TTS 请求路径：
 *   TTSConfig.getFormattedParams(text) -> Http.bytes(params)
 * 用于验证 tts.json 中的 URL/body 经 app 自身编码后会变成什么，并实测取字节是否成功。
 *
 * 用法: java TtsProbe <format|fetch> <textFile(UTF-8)> <outDir>
 *  - format: 只打印每个配置格式化后的 URL/body（不联网）
 *  - fetch : 按 app 相同路径取音频字节，写入 outDir/<name>.bin，并打印长度/头部十六进制
 */
public class TtsProbe {

    static class Cfg {
        String name;
        String url;
        String method;
        String body;

        Cfg(String name, String url, String method, String body) {
            this.name = name;
            this.url = url;
            this.method = method;
            this.body = body;
        }
    }

    static List<Cfg> configs() {
        List<Cfg> list = new ArrayList<>();
        // ---- 内置引擎：百度 POST（tts.json 原样） ----
        list.add(new Cfg("builtin_baidu_post",
                "http://tts.baidu.com/text2audio",
                "POST",
                "tex={{text}}&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio"));
        list.add(new Cfg("builtin_baidu_post_https",
                "https://tts.baidu.com/text2audio",
                "POST",
                "tex={{text}}&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio"));
        // 百度 GET 形式（per=0 度小美）
        list.add(new Cfg("baidu_get_per0",
                "http://tts.baidu.com/text2audio?tex={{text}}&per=0&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5",
                "GET", null));
        // ---- 内置引擎：思必驰（tts.json 原样，双 && 保留） ----
        list.add(new Cfg("builtin_dui_gdfanfp",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=gdfanfp&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_zhilingfp",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=zhilingfp&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_zxcmp",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=zxcmp&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_gqlanfp",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=gqlanfp&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_geyoump",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=geyoump&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_ppangf_csn",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=ppangf_csn&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        list.add(new Cfg("builtin_dui_gdgmfp",
                "https://dds.dui.ai/runtime/v1/synthesize?voiceId=gdgmfp&text={{text}}&&speed=10&volume=100&audioType=mp3",
                "GET", null));
        // ---- 候选替代 ----
        list.add(new Cfg("youdao_dictvoice",
                "https://dict.youdao.com/dictvoice?audio={{text}}&le=zh",
                "GET", null));
        list.add(new Cfg("youdao_fanyivoice",
                "https://tts.youdao.com/fanyivoice?word={{text}}&le=zh&keyfrom=speaker-target",
                "GET", null));
        list.add(new Cfg("baidu_fanyi_gettts",
                "https://fanyi.baidu.com/gettts?lan=zh&text={{text}}&spd=5&source=web",
                "GET", null));
        list.add(new Cfg("sogou_synthesis",
                "https://fanyi.sogou.com/reventondc/synthesis?text={{text}}&speed=1&lang=zh-CHS&from=translateweb&speaker=6",
                "GET", null));
        list.add(new Cfg("google_translate_tts",
                "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=zh-CN&q={{text}}",
                "GET", null));
        // ---- 本地回声服务：验证 app 真正发出的查询串/正文（端口见 echo_server.py） ----
        list.add(new Cfg("echo_get",
                "http://127.0.0.1:18923/tts?text={{text}}&le=zh",
                "GET", null));
        list.add(new Cfg("echo_post",
                "http://127.0.0.1:18923/tts",
                "POST",
                "tex={{text}}&per=106&lan=zh&aue=3"));
        // ---- 本地 TTS 服务（edge-tts / SAPI），验证 app 能否播放本地服务返回的音频 ----
        list.add(new Cfg("local_edge_tts",
                "http://127.0.0.1:18523/tts?text={{text}}",
                "GET", null));
        list.add(new Cfg("local_sapi_tts",
                "http://127.0.0.1:18524/tts?text={{text}}",
                "GET", null));
        return list;
    }

    public static void main(String[] args) throws Exception {
        String mode = args.length > 0 ? args[0] : "format";
        String textFile = args.length > 1 ? args[1] : "text_short.txt";
        String outDir = args.length > 2 ? args[2] : "samples_java";
        String filter = args.length > 3 ? args[3] : null;   // 逗号分隔的子串过滤，null=全部
        String text = new String(Files.readAllBytes(Paths.get(textFile)), StandardCharsets.UTF_8).trim();
        if (mode.equals("format")) {
            System.out.println("TEXT_LEN=" + text.length() + " TEXT=" + text);
        }
        File dir = new File(outDir);
        dir.mkdirs();
        for (Cfg c : configs()) {
            if (filter != null && !matches(c.name, filter)) {
                continue;
            }
            TTSConfig cfg = new TTSConfig();
            cfg.setName(c.name);
            RequestParams p = new RequestParams();
            p.setUrl(c.url);
            p.setMethod(c.method);
            if (c.body != null) {
                p.setBody(c.body);
            }
            cfg.setParams(p);
            RequestParams formatted = cfg.getFormattedParams(text);
            System.out.println("=== " + c.name + " [" + c.method + "]");
            System.out.println("URL=" + formatted.getUrl());
            if (formatted.getBody() != null) {
                System.out.println("BODY=" + formatted.getBody());
            }
            if (mode.equals("fetch")) {
                long t0 = System.currentTimeMillis();
                try {
                    byte[] bytes = Http.bytes(formatted);
                    long ms = System.currentTimeMillis() - t0;
                    File out = new File(dir, c.name + ".bin");
                    Files.write(out.toPath(), bytes);
                    System.out.println("RESULT=OK bytes=" + bytes.length + " ms=" + ms + " head=" + hex(bytes, 16));
                } catch (Throwable e) {
                    long ms = System.currentTimeMillis() - t0;
                    String msg = e.getClass().getSimpleName() + ": " + String.valueOf(e.getMessage()).replace('\n', ' ');
                    System.out.println("RESULT=FAIL ms=" + ms + " err=" + msg);
                }
            }
            System.out.println();
        }
    }

    private static boolean matches(String name, String filter) {
        for (String f : filter.split(",")) {
            if (name.contains(f.trim())) {
                return true;
            }
        }
        return false;
    }

    private static String hex(byte[] b, int n) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Math.min(n, b.length); i++) {
            sb.append(String.format("%02X ", b[i]));
        }
        return sb.toString().trim();
    }
}
