#!/usr/bin/env node
/**
 * Browser automation script for agents.
 * Runs a sequence of actions on a page and returns results.
 *
 * Usage: NODE_PATH=$(npm root -g) node browse.js <json_instructions>
 *
 * Instructions JSON:
 * {
 *   "url": "https://example.com",
 *   "viewport": { "width": 1280, "height": 720 },
 *   "actions": [
 *     { "action": "screenshot", "output": "./page.png", "fullPage": true },
 *     { "action": "click", "selector": "button.submit" },
 *     { "action": "type", "selector": "input[name=email]", "text": "test@test.com" },
 *     { "action": "wait", "ms": 2000 },
 *     { "action": "waitFor", "selector": ".results" },
 *     { "action": "screenshot", "output": "./after.png" },
 *     { "action": "text", "selector": ".results" },
 *     { "action": "evaluate", "script": "document.title" },
 *     { "action": "pdf", "output": "./page.pdf" }
 *   ]
 * }
 *
 * Or pass a file path: node browse.js @instructions.json
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function run() {
  let input = process.argv[2];
  if (!input) {
    console.error('Usage: node browse.js <json_instructions | @file.json>');
    process.exit(1);
  }

  // Load from file if prefixed with @
  if (input.startsWith('@')) {
    input = fs.readFileSync(input.slice(1), 'utf8');
  }

  const instructions = JSON.parse(input);
  const viewport = instructions.viewport || { width: 1280, height: 720 };
  const results = [];

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport });

  if (instructions.url) {
    await page.goto(instructions.url, {
      waitUntil: instructions.waitUntil || 'networkidle',
      timeout: instructions.timeout || 30000
    });
  }

  for (const step of (instructions.actions || [])) {
    try {
      switch (step.action) {
        case 'screenshot': {
          const output = step.output || `/tmp/screenshot-${Date.now()}.png`;
          await page.screenshot({
            path: output,
            fullPage: step.fullPage || false
          });
          results.push({ action: 'screenshot', output, status: 'ok' });
          break;
        }
        case 'click':
          await page.click(step.selector, { timeout: step.timeout || 5000 });
          results.push({ action: 'click', selector: step.selector, status: 'ok' });
          break;
        case 'type':
          await page.fill(step.selector, step.text);
          results.push({ action: 'type', selector: step.selector, status: 'ok' });
          break;
        case 'press':
          await page.keyboard.press(step.key);
          results.push({ action: 'press', key: step.key, status: 'ok' });
          break;
        case 'wait':
          await new Promise(r => setTimeout(r, step.ms || 1000));
          results.push({ action: 'wait', ms: step.ms, status: 'ok' });
          break;
        case 'waitFor':
          await page.waitForSelector(step.selector, { timeout: step.timeout || 10000 });
          results.push({ action: 'waitFor', selector: step.selector, status: 'ok' });
          break;
        case 'navigate':
          await page.goto(step.url, {
            waitUntil: step.waitUntil || 'networkidle',
            timeout: step.timeout || 30000
          });
          results.push({ action: 'navigate', url: step.url, status: 'ok' });
          break;
        case 'text': {
          const el = step.selector ? await page.$(step.selector) : page;
          const text = step.selector
            ? await el.textContent()
            : await page.evaluate(() => document.body.innerText);
          results.push({ action: 'text', text: text?.slice(0, 5000), status: 'ok' });
          break;
        }
        case 'evaluate': {
          const value = await page.evaluate(step.script);
          results.push({ action: 'evaluate', value, status: 'ok' });
          break;
        }
        case 'pdf': {
          const output = step.output || `/tmp/page-${Date.now()}.pdf`;
          await page.pdf({ path: output, format: step.format || 'A4' });
          results.push({ action: 'pdf', output, status: 'ok' });
          break;
        }
        default:
          results.push({ action: step.action, status: 'error', error: 'Unknown action' });
      }
    } catch (err) {
      results.push({ action: step.action, status: 'error', error: err.message });
    }
  }

  await browser.close();
  console.log(JSON.stringify({ results }, null, 2));
}

run().catch(e => {
  console.error(e.message);
  process.exit(1);
});
