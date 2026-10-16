import { safeSVG, verifyImages } from './svg.js';
let worker;
let rejectRendering;
window.cancelRendering = () => { worker?.terminate(); worker = undefined; rejectRendering?.(new Error('cancelled')); rejectRendering = undefined; };
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
window.renderDocument = async (base64, thumbnail) => {
    window.cancelRendering();
    pages.replaceChildren();
    document.body.classList.toggle('thumbnail', thumbnail);
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    let count = 0, removed = 0, images = 0, target = 0;
    const engineWarnings = await new Promise((resolve,reject) => {
        rejectRendering = reject;
        worker = new Worker(new URL('./engine-worker.js',import.meta.url),{type:'module'});
        worker.onerror = () => { window.cancelRendering(); reject(new Error('engineFailed')); };
        worker.onmessage = ({data}) => {
            try {
                if (data.kind === 'start') count = data.count;
                else if (data.kind === 'page') {
                    const sanitized = safeSVG(data.source); removed += sanitized.removed;
                    images += sanitized.svg.querySelectorAll('image').length;
                    const page = document.createElement('section'); page.className = 'page';
                    page.setAttribute('aria-label',`${data.index+1}쪽`);
                    page.append(sanitized.svg); pages.append(page); target++;
                } else if (data.kind === 'done') {
                    worker.terminate(); worker = undefined; rejectRendering = undefined; resolve(data.warnings);
                } else if (data.kind === 'error') throw new Error('engineFailed');
            } catch (error) { window.cancelRendering(); reject(error); }
        };
        worker.postMessage({bytes,thumbnail},[bytes.buffer]);
    });
    document.getElementById('page-number').max = String(count);
    const imageFailures = await verifyImages(pages);
    const warnings = removed + imageFailures + engineWarnings;
    document.getElementById('status').textContent = `${count}쪽 · 실험적 미리보기: 글꼴·배치 차이 가능${warnings ? ` · 표시 주의 ${warnings}건 (이미지 실패 ${imageFailures}건)` : ''}`;
    await new Promise(resolve => setTimeout(resolve, 0));
    const svg = pages.querySelector('svg');
    const box = svg.viewBox.baseVal;
    return {pages: count, rendered: target, textCharacters: pages.textContent.length,
            images, imageFailures, sanitizedElements:removed, engineWarnings, width: box.width || svg.width.baseVal.value,
            height: box.height || svg.height.baseVal.value, fidelityVerified: false};
};
const request = new URL(location.href).searchParams.get('request');
window.webkit?.messageHandlers.ready.postMessage({request,ready:true});
