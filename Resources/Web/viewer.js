import { safeSVG, verifyImages } from './svg.js';
let worker;
let rejectRendering;
window.cancelRendering = () => { worker?.terminate(); worker = undefined; rejectRendering?.(new Error('cancelled')); rejectRendering = undefined; };
const pages = document.getElementById('pages');
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
    const imageFailures = await verifyImages(pages);
    await new Promise(resolve => setTimeout(resolve, 0));
    const svg = pages.querySelector('svg');
    const box = svg.viewBox.baseVal;
    return {pages: count, rendered: target, textCharacters: pages.textContent.length,
            images, imageFailures, sanitizedElements:removed, engineWarnings, width: box.width || svg.width.baseVal.value,
            height: box.height || svg.height.baseVal.value, fidelityVerified: false};
};
const request = new URL(location.href).searchParams.get('request');
window.webkit?.messageHandlers.ready.postMessage({request,ready:true});
