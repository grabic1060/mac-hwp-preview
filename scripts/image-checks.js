const { safeSVG, verifyImages } = await import('hwp-preview://assets/svg.js');
const assert = (value, message) => { if (!value) throw new Error(message); };
const source = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
<a href="https://example.invalid"><text x="10" y="20">한글 링크 본문</text></a>
<script>window.injected=true</script><foreignObject><div xmlns="http://www.w3.org/1999/xhtml">bad</div></foreignObject>
<rect onclick="window.injected=true" style="fill:url(https://example.invalid/image)"/>
<image x="10" y="30" width="80" height="60" href="https://example.invalid/image"/>
<image x="110" y="30" width="80" height="60" href="data:image/png;base64,AAAA"/>
<defs><clipPath id="clip"><rect width="40" height="40"/></clipPath></defs><g clip-path="url(#clip)"><text>셀 안 본문</text></g>
</svg>`;
const {svg,removed} = safeSVG(source);
assert(removed >= 5, 'unsafe content diagnostics');
assert(svg.textContent.includes('한글 링크 본문'), 'link text must be preserved');
assert(svg.querySelector('[clip-path]').getAttribute('clip-path') === 'url(#clip)', 'local clipping retained');
assert(!svg.querySelector('script,foreignObject,a,[onclick]'), 'active content removed');
assert(!svg.querySelector('[href^="https:"]'), 'remote image removed');
assert(await verifyImages(svg) === 2, 'image failures counted');
assert(svg.querySelector('rect[x="10"][y="30"][width="80"][height="60"]'), 'missing image geometry retained');
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
const valid = safeSVG(`<svg xmlns="http://www.w3.org/2000/svg"><image width="1" height="1" href="data:image/png;base64,${png}"/></svg>`).svg;
assert(await verifyImages(valid) === 0, 'embedded PNG decoding');
const violations=[];
const listener = event => violations.push(event.violatedDirective);
document.addEventListener('securitypolicyviolation',listener);
try { await fetch('https://example.invalid/document-test'); } catch {}
await new Promise(resolve => setTimeout(resolve,100));
document.removeEventListener('securitypolicyviolation',listener);
assert(violations.some(v=>v.startsWith('connect-src')), 'CSP blocks external requests before network');
assert(!window.injected, 'script must not execute');
return {sanitizer:true,imagePlaceholders:true,embeddedPNG:true,networkPolicy:true};
