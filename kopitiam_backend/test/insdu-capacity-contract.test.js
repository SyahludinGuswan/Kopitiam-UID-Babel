'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../ZZZZZZ_InsduJurusanContract.js'),'utf8');
function load(){const sandbox={};vm.createContext(sandbox);vm.runInContext(source,sandbox);return sandbox;}
test('accepts only supported transformer capacities',()=>{const api=load();for(const value of [25,50,100,160,200,250])assert.equal(api.validateInsduCapacity_({Kapasitas:value}),value);for(const value of ['',0,75,300,'abc'])assert.throws(()=>api.validateInsduCapacity_({Kapasitas:value}),e=>e.insduCode==='INSDU_CAPACITY_INVALID');});
test('calculates maximum current per phase at nominal 400 V',()=>{const api=load();assert.ok(Math.abs(api.insduMaximumPhaseCurrent_(100)-144.337)<0.01);assert.ok(Math.abs(api.insduMaximumPhaseCurrent_(250)-360.844)<0.01);});
