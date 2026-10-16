import init, { HwpDocument } from './rhwp.js';
const canvas = new OffscreenCanvas(1,1);
const context = canvas.getContext('2d');
globalThis.measureTextWidth = (font,text) => { context.font = font; return context.measureText(text).width; };
const ready = init({module_or_path:new URL('./rhwp_bg.wasm',import.meta.url)});
onmessage = async ({data}) => {
    let document;
    try {
        await ready;
        document = new HwpDocument(data.bytes);
        const count = document.pageCount();
        if (!Number.isInteger(count) || count < 1 || count > 500) throw new Error('pageLimit');
        postMessage({kind:'start',count});
        let size = 0;
        for (let index = 0; index < (data.thumbnail ? 1 : count); index++) {
            const source = document.renderPageSvg(index);
            size += source.length * 2;
            if (size > 100 * 1024 * 1024) throw new Error('outputLimit');
            postMessage({kind:'page',index,source});
        }
        const warnings = JSON.parse(document.getValidationWarnings()).count || 0;
        postMessage({kind:'done',warnings});
    } catch { postMessage({kind:'error'}); }
    finally { document?.free(); }
};
