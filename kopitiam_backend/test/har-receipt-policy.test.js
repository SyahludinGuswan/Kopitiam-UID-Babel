'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../ZZZZZZZZZZZ_HarReceiptPolicy.js'),'utf8');
function run(status){let required=null;const sandbox={receiptConfigureTransport_(){},receiptValidateRows_:rows=>rows,syncHarCommitted_:()=>({success:true,receipts:[]}),receiptFinalize_:(result,rows,photoRequired)=>{required=photoRequired;return result;},normalize_:v=>String(v??'').trim().toLowerCase(),fail_:(kode,message)=>({success:false,kode,message})};vm.createContext(sandbox);vm.runInContext(source,sandbox);sandbox.syncHarReceiptByStatus_('token','jar',[{'Status WO':status}]);return required;}
test('Har progress does not require photo receipt',()=>assert.equal(run('Progress Pekerjaan'),false));
test('completed Har requires photo receipt',()=>assert.equal(run('Selesai'),true));
