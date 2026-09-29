#!/usr/bin/env node
const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const geometry=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../config/quickshell/win8/WorkspaceGeometry.js'),'utf8').replace(/^\.pragma library\s*/,''),geometry);
let viewport=geometry.viewport({x:2560,y:-200,width:1920,height:1080,scale:1.5},null);
assert.equal(viewport.width,1280);assert.equal(viewport.height,720);
const rect=geometry.rectangle({at:[2580,-180],size:[700,300]},viewport);assert.equal(rect.x,20);assert.equal(rect.y,20);assert.equal(rect.width,700);
assert.equal(geometry.fit(640,360,viewport),.5);
viewport=geometry.viewport({x:-1080,y:0,width:1920,height:1080,scale:1,transform:1},null);assert.equal(viewport.width,1080);assert.equal(viewport.height,1920);
viewport=geometry.viewport({width:2560,height:1440,scale:2},{width:1280,height:720});assert.equal(viewport.width,1280);
const windows=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../config/quickshell/win8/WindowList.js'),'utf8').replace(/^\.pragma library\s*/,''),windows);
function w(address,active,order){return {address,activated:active,lastIpcObject:{mapped:true,focusHistoryID:order}};}
const current=w('current',true,3),last=w('last',false,0),older=w('older',false,2);
assert.deepEqual(Array.from(windows.mru([older,last,current]),v=>v.address),['current','last','older']);
console.log('PASS scaled/rotated monitor composition, negative positions, full-desktop fit and active-first MRU');
