.pragma library

function isMapped(window) {
    return !!window && !!window.address && window.lastIpcObject?.mapped === true;
}

function sorted(values) {
    return values.filter(isMapped).slice().sort((a, b) =>
        (a.workspace?.id || 0) - (b.workspace?.id || 0)
        || (a.lastIpcObject.at?.[1] || 0) - (b.lastIpcObject.at?.[1] || 0)
        || (a.lastIpcObject.at?.[0] || 0) - (b.lastIpcObject.at?.[0] || 0)
        || a.address.localeCompare(b.address));
}

function sameObjects(previous, next) {
    return previous.length === next.length && previous.every((window, index) => window === next[index]);
}

function reconcile(previous, current, selectedIndex, appendNew) {
    const live = new Map(current.filter(isMapped).map(window => [window.address, window]));
    const selectedAddress = previous[selectedIndex]?.address;
    const next = previous.filter(window => live.has(window?.address)).map(window => live.get(window.address));
    if (appendNew) {
        const seen = new Set(next.map(window => window.address));
        current.filter(isMapped).forEach(window => {
            if (!seen.has(window.address)) { next.push(window); seen.add(window.address); }
        });
    }
    const retained = next.findIndex(window => window.address === selectedAddress);
    return { windows: next, selected: retained >= 0 ? retained : Math.max(0, Math.min(selectedIndex, next.length - 1)) };
}
