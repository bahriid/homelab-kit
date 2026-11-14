// Pass every request to the origin. If the origin is unreachable, browsers get a static page
// instead of Cloudflare's error screen; API and sync clients get the original error so they retry.
const DOWN = new Set([502, 504, 520, 521, 522, 523, 524, 525, 526, 530])

export default {
  async fetch(request) {
    let res
    try {
      res = await fetch(request)
    } catch {
      res = null
    }
    if (res && !DOWN.has(res.status)) return res
    if (!(request.headers.get('accept') || '').includes('text/html')) {
      return res ?? new Response('origin unreachable', { status: 503, headers: { 'retry-after': '120' } })
    }
    return new Response(PAGE, {
      status: 503,
      headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'retry-after': '120' },
    })
  },
}

const PAGE = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>Back soon | __SITE_NAME__</title>
<style>
:root{--bg:#f4f5f2;--fg:#1c1e1a;--mute:#5d6358;--line:#d8dbd3;--ok:#2f6f5e}
@media (prefers-color-scheme:dark){:root{--bg:#121411;--fg:#eceee8;--mute:#9aa190;--line:#2a2e27;--ok:#7cc5ae}}
*{box-sizing:border-box}html,body{margin:0;height:100%}
body{background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;display:grid;place-items:center;padding:24px 16px}
main{max-width:520px;width:100%}
.k{font:12px/1 ui-monospace,Menlo,monospace;letter-spacing:.12em;text-transform:uppercase;color:var(--ok)}
h1{font-size:clamp(26px,6vw,36px);line-height:1.2;margin:14px 0 10px}
p{color:var(--mute);margin:0 0 12px}
.box{margin-top:22px;border:1px solid var(--line);border-radius:10px;padding:14px 16px;font:13px/1.7 ui-monospace,Menlo,monospace;color:var(--mute)}
button{margin-top:18px;background:var(--fg);color:var(--bg);border:0;border-radius:8px;padding:11px 18px;font:inherit;font-weight:600;cursor:pointer}
</style></head><body><main>
<div class="k">Server offline</div>
<h1>__SITE_NAME__ is taking a short break.</h1>
<p>This site runs on a server at home, and it can't be reached right now, usually because of power or internet. Your data is safe.</p>
<p>This page checks again every 2 minutes.</p>
<div class="box">HOST <span id="h"></span><br>CHECKED <span id="t"></span></div>
<button type="button" onclick="location.reload()">Try again</button>
<p style="margin-top:22px;font-size:14px">__CONTACT__</p>
</main>
<script>
document.getElementById('h').textContent=location.host
document.getElementById('t').textContent=new Date().toLocaleString()
setTimeout(function(){location.reload()},120000)
</script></body></html>`
