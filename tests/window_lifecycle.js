#!/usr/bin/env node
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../config/quickshell/win8/WindowList.js'), 'utf8').replace(/^\.pragma library\s*/, ''), context);
const make = (address, workspace, mapped = true) => ({address, workspace: {id: workspace}, lastIpcObject: {mapped, at: [10, 10]}});
const terminal = make('aaa', 2), loader = make('bbb', 3), main = make('ccc', 3);
assert.equal(context.isMapped({address: 'ghost', lastIpcObject: {}}), false);
assert.equal(context.isMapped(make('unmapped', 3, false)), false);
assert.equal(context.isMapped(null), false);
const current = context.sorted([main, {address: 'ghost', lastIpcObject: {}}, terminal]);
assert.deepEqual(Array.from(current, w => w.address), ['aaa', 'ccc']);
let next = context.reconcile([terminal, loader, main], current, 1, true);
assert.deepEqual(Array.from(next.windows, w => w.address), ['aaa', 'ccc']);
assert.equal(next.selected, 1); // Removing selected loader picks the following main window.
next = context.reconcile([terminal, loader, main], current, 2, true);
assert.equal(next.selected, 1); // Preserve selected main when an earlier entry disappears.
next = context.reconcile([terminal, loader], current, 1, true);
assert.deepEqual(Array.from(next.windows, w => w.address), ['aaa', 'ccc']);
const replacement = make('bbb', 3);
assert.equal(context.sameObjects([loader], [replacement]), false); // Address can be reused for a new QObject.
next = context.reconcile([loader], [replacement], 0, true);
assert.equal(next.windows[0], replacement);
assert.equal(context.sameObjects([terminal, main], [terminal, main]), true); // Title updates don't rebuild delegates.
next = context.reconcile([loader], [], 0, true);
assert.equal(next.windows.length, 0); assert.equal(next.selected, 0);
console.log('PASS closed loader filtering, live Alt+Tab reconciliation, selection preservation and reused-address replacement');
