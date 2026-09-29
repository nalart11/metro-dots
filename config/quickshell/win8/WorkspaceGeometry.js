.pragma library
function viewport(monitor, screen) {
    const scale=monitor.scale || 1;
    const rotated=(monitor.transform || 0)%2!==0;
    return {x:monitor.x || 0,y:monitor.y || 0,
        width:screen?.width || (rotated ? monitor.height : monitor.width)/scale || 1280,
        height:screen?.height || (rotated ? monitor.width : monitor.height)/scale || 720};
}
function rectangle(window, monitor) {
    return {x:(window.at?.[0] || 0)-monitor.x,y:(window.at?.[1] || 0)-monitor.y,
        width:Math.max(1,window.size?.[0] || 1),height:Math.max(1,window.size?.[1] || 1)};
}
function fit(width,height,viewport) {return Math.max(.001,Math.min(width/viewport.width,height/viewport.height));}
