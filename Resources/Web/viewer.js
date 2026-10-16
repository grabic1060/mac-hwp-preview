import init, { HwpDocument } from './rhwp.js';
const canvas = document.createElement('canvas');
const context = canvas.getContext('2d');
globalThis.measureTextWidth = (font, text) => { context.font = font; return context.measureText(text).width; };
const ready = init({module_or_path: new URL('./rhwp_bg.wasm', import.meta.url)});
let doc;
let scale = 1;
const pages = document.getElementById('pages');
function zoom(value) { scale = value; pages.style.width = `${100 * scale}%`; }
document.getElementById('minus').onclick = () => zoom(Math.max(0.5, scale - 0.25));
document.getElementById('plus').onclick = () => zoom(Math.min(3, scale + 0.25));
document.getElementById('fit').onclick = () => zoom(1);
document.getElementById('go').onclick = () => {
    const number = document.getElementById('page-number').valueAsNumber;
    if (Number.isInteger(number) && number >= 1 && number <= pages.children.length)
        pages.children[number - 1].scrollIntoView({block:'start'});
};
function safeSVG(source) {
    const parsed = new DOMParser().parseFromString(source, 'image/svg+xml');
    if (parsed.querySelector('parsererror') || parsed.documentElement.localName !== 'svg') throw new Error('invalidSVG');
    for (const node of parsed.querySelectorAll('script,foreignObject,iframe,object,embed,style,a,animate,set')) node.remove();
    for (const node of parsed.querySelectorAll('*')) {
        for (const attr of [...node.attributes]) {
            if (/^on/i.test(attr.name)) node.removeAttributeNode(attr);
            if (['href','xlink:href','src'].includes(attr.name) && !/^(#|data:image\/(png|jpeg|gif|webp);base64,)/i.test(attr.value)) node.removeAttributeNode(attr);
            if (/url\(/i.test(attr.value) && !/^url\(#[a-z0-9_-]+\)$/i.test(attr.value)) node.removeAttributeNode(attr);
        }
    }
    return document.importNode(parsed.documentElement, true);
}
window.renderDocument = async (base64, thumbnail) => {
    await ready;
    if (doc) doc.free();
    pages.replaceChildren();
    document.body.classList.toggle('thumbnail', thumbnail);
    const data = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    doc = new HwpDocument(data);
    const count = doc.pageCount();
    if (!Number.isInteger(count) || count < 1 || count > 500) throw new Error('pageLimit');
    let bytes = 0;
    const target = thumbnail ? 1 : count;
    for (let i = 0; i < target; i++) {
        const source = doc.renderPageSvg(i);
        bytes += source.length;
        if (bytes > 100 * 1024 * 1024) throw new Error('outputLimit');
        const page = document.createElement('section'); page.className = 'page'; page.setAttribute('aria-label', `${i+1}쪽`);
        page.append(safeSVG(source)); pages.append(page);
        // Yield between pages so navigation/cancellation can release the WebView.
        if (i % 4 === 0) await new Promise(resolve => setTimeout(resolve, 0));
    }
    document.getElementById('page-number').max = String(count);
    document.getElementById('status').textContent = `${count}쪽 · 실험적 미리보기: 글꼴·배치 차이 가능`;
    await Promise.all([...pages.querySelectorAll('image')].map(async el => {
        const image = new Image(); image.src = el.getAttribute('href') || el.getAttribute('xlink:href') || '';
        try { await image.decode(); } catch { /* counted separately below */ }
    }));
    await new Promise(resolve => setTimeout(resolve, 0));
    const svg = pages.querySelector('svg');
    const box = svg.viewBox.baseVal;
    return {pages: count, rendered: target, textCharacters: pages.textContent.length,
            images: pages.querySelectorAll('image').length, width: box.width || svg.width.baseVal.value,
            height: box.height || svg.height.baseVal.value, fidelityVerified: false};
};
const request = new URL(location.href).searchParams.get('request');
ready.then(() => window.webkit?.messageHandlers.ready.postMessage({request,ready:true})).catch(() => window.webkit?.messageHandlers.ready.postMessage({request,ready:false}));
