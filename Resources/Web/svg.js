const NS = 'http://www.w3.org/2000/svg';
const allowed = new Set(['svg','g','defs','clipPath','mask','path','rect','line','polyline','polygon',
    'circle','ellipse','text','tspan','image','linearGradient','radialGradient','stop','pattern','use','title','desc']);
const reference = /^#[a-z0-9_.:-]+$/i;
const raster = /^data:image\/(png|jpeg|gif|webp|bmp|tiff);base64,[a-z0-9+/=\s]+$/i;

export function safeSVG(source) {
    const parsed = new DOMParser().parseFromString(source, 'image/svg+xml');
    if (parsed.querySelector('parsererror') || parsed.documentElement.localName !== 'svg' ||
        parsed.documentElement.namespaceURI !== NS) throw new Error('invalidSVG');
    let removed = 0;
    for (const node of [...parsed.querySelectorAll('*')]) {
        if (node.localName === 'a' && node.namespaceURI === NS) {
            node.replaceWith(...node.childNodes); removed++; continue;
        }
        if (!allowed.has(node.localName) || node.namespaceURI !== NS) {
            node.remove(); removed++; continue;
        }
        for (const attr of [...node.attributes]) {
            const name = attr.localName.toLowerCase();
            let unsafe = /^on/i.test(name) || ['base','src','class'].includes(name);
            if (name === 'href') unsafe ||= !(reference.test(attr.value) || (node.localName === 'image' && raster.test(attr.value)));
            // CSS escapes and comments can disguise URL tokens; generated SVG needs neither.
            if (name === 'style') unsafe ||= /[\\@]|\/\*|url\s*\(/i.test(attr.value);
            if (/url\s*\(/i.test(attr.value)) unsafe ||= !/^url\(#[a-z0-9_.:-]+\)$/i.test(attr.value);
            if (unsafe) { node.removeAttributeNode(attr); removed++; }
        }
    }
    for (const image of parsed.querySelectorAll('image')) {
        const href = image.getAttribute('href') || image.getAttribute('xlink:href') || '';
        if (raster.test(href)) {
            image.setAttribute('data-preview-image',href);
            image.removeAttribute('href'); image.removeAttribute('xlink:href');
        }
    }
    return {svg: document.importNode(parsed.documentElement, true), removed};
}

export async function verifyImages(root) {
    let failed = 0;
    for (const element of root.querySelectorAll('image')) {
        const source = element.getAttribute('data-preview-image') || element.getAttribute('href') || element.getAttribute('xlink:href') || '';
        if (reference.test(source)) continue;
        const image = new Image();
        try {
            if (!raster.test(source)) throw new Error('unsupportedImage');
            const accepted = await window.webkit.messageHandlers.imageBudget.postMessage(source);
            if (!accepted) throw new Error('imageLimit');
            image.src = source;
            await image.decode();
            element.setAttribute('href',source); element.removeAttribute('data-preview-image');
        } catch {
            failed++;
            // Keep the image's original rectangle and transform, so the missing content is visible.
            const group = document.createElementNS(NS, 'g');
            const rect = document.createElementNS(NS, 'rect');
            for (const key of ['x','y','width','height','transform']) {
                if (element.hasAttribute(key)) rect.setAttribute(key,element.getAttribute(key));
            }
            rect.setAttribute('fill','#fff3d6'); rect.setAttribute('stroke','#a65a00');
            const title = document.createElementNS(NS,'title'); title.textContent = '이미지를 표시할 수 없습니다';
            group.append(title,rect); element.replaceWith(group);
        }
    }
    return failed;
}
