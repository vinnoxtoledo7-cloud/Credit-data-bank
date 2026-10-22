// Uses isolated temporary QA credentials supplied outside the repository.
const {chromium}=require('playwright');
const fs=require('node:fs');const assert=require('node:assert/strict');
(async()=>{
 const users=JSON.parse(fs.readFileSync(process.env.QA_USERS_FILE,'utf8'));
 const browser=await chromium.launch({headless:true});
 const context=await browser.newContext({viewport:{width:390,height:844}});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const base=process.env.QA_BASE_URL||'http://127.0.0.1:8765';
 async function login(u){await page.goto(base+'/credit-clients.html');await page.locator('#auth [name=email]').fill(u.email);await page.locator('#auth [name=password]').fill(u.password);await page.locator('#auth button').click();await page.locator('#work').waitFor({state:'visible'});await page.locator('#source option').nth(1).waitFor({state:'attached'});}
 try{
 await login(users[0]);
 await page.locator('#beneficiary-form [name=account]').fill(users[1].account);await page.locator('#beneficiary-form [name=nickname]').fill('QA <img src=x onerror=alert(1)>');await page.locator('#beneficiary-form button').click();await page.locator('#beneficiaries .row').waitFor();
 assert.equal(await page.locator('#beneficiaries img').count(),0);
 await page.locator('#source').selectOption(users[0].account);await page.locator('#beneficiary').selectOption({index:1});await page.locator('#transfer-form [name=amount]').fill('12.34');await page.locator('#transfer-form [name=description]').fill('QA browser simulation');await page.locator('#send').click();await page.locator('#review').waitFor({state:'visible'});await page.locator('#confirm').click();await page.locator('#receipt').waitFor({state:'visible'});
 assert.match(await page.locator('#receipt-content').innerText(),/12,34/);
 const downloadPromise=page.waitForEvent('download');await page.locator('#download').click();const download=await downloadPromise;assert.match(download.suggestedFilename(),/^simulacao-.*\.txt$/);
 await page.locator('#close-receipt').click();await page.locator('#history button').first().waitFor();await page.reload();await page.locator('#history button').first().click();await page.locator('#receipt').waitFor({state:'visible'});assert.match(await page.locator('#receipt-content').innerText(),/QA browser simulation/);await page.locator('#close-receipt').click();
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
 await page.screenshot({path:'/tmp/cdb-mobile.png',fullPage:true});
 await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});
 await login(users[1]);await page.locator('#direction').selectOption('received');await page.locator('#history button').first().click();await page.locator('#receipt').waitFor({state:'visible'});assert.match(await page.locator('#receipt-content').innerText(),/12,34/);await page.locator('#close-receipt').click();
 assert.equal(await page.locator('#beneficiaries .row').count(),0);
 assert.match(await page.locator('#source').innerText(),/12,34/);
 await page.setViewportSize({width:1280,height:900});await page.screenshot({path:'/tmp/cdb-desktop.png',fullPage:true});
 assert.deepEqual(errors,[]);await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});
 console.log('PASS: real Supabase login, beneficiary, XSS escaping, reviewed transfer, persisted receipt, download, recipient access and balance, mobile/desktop layout, logout; no JS errors');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1)});
