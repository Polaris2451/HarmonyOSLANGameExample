#!/usr/bin/env node
/**
 * 无头联机客户端。没有第二台设备时，用它冒充一个玩家。
 *
 * 用法：
 *   node tools/headless-client.mjs <url> <昵称> [--guessFile=<路径>]
 *
 * --guessFile 用于当「猜词方」：客户端每秒读一次这个文件，
 * 一旦里面有内容，就在作画阶段把它当作答案发出去。
 * 之所以用文件而不是命令行参数，是因为答案要等画手选完词之后才知道。
 *
 * 依赖 Node 22+ 内置的 WebSocket，不需要 npm install。
 */

import fs from 'node:fs';

const url = process.argv[2] ?? 'ws://127.0.0.1:8080';
const nickname = process.argv[3] ?? 'Bot';
const guessArg = process.argv.find((a) => a.startsWith('--guessFile='));
const guessFile = guessArg ? guessArg.slice('--guessFile='.length) : '';
const PROTOCOL_VERSION = 1;

let seq = 0;
let guessSent = false;
let drawing = false;
const ws = new WebSocket(url);

function send(type, body) {
  ws.send(JSON.stringify({
    v: PROTOCOL_VERSION,
    t: type,
    seq: seq++,
    body: JSON.stringify(body)
  }));
}

ws.addEventListener('open', () => {
  console.log('[' + nickname + '] connected ' + url);
  send('hello', { nickname, protocolVersion: PROTOCOL_VERSION, hostToken: '' });
  setInterval(() => send('ping', {}), 3000);
});

ws.addEventListener('message', (ev) => {
  const raw = typeof ev.data === 'string' ? ev.data : '';
  let env;
  try { env = JSON.parse(raw); } catch { return; }
  let body = {};
  try { body = JSON.parse(env.body); } catch { /* 忽略 */ }
  if (env.t === 'pong') { return; }
  if (env.t === 'state') {
    let st = {};
    try { st = JSON.parse(body.payload); } catch { /* 忽略 */ }
    console.log('[' + nickname + '] state phase=' + st.phase + ' round=' + st.round +
      ' scores=' + JSON.stringify((st.players || []).map((p) => p.nickname + ':' + p.score)));
    drawing = st.phase === 'drawing';
    return;
  }
  console.log('[' + nickname + '] <- ' + env.t + ' ' + JSON.stringify(body));
  if (env.t === 'error') {
    console.log('[' + nickname + '] rejected: ' + body.code);
    process.exit(3);
  }
});

// 猜词：等画手选完词、进入作画阶段后再发
if (guessFile.length > 0) {
  setInterval(() => {
    if (guessSent || !drawing) { return; }
    let word = '';
    try { word = (fs.readFileSync(guessFile, 'utf8') || '').trim(); } catch { return; }
    if (word.length === 0) { return; }
    guessSent = true;
    console.log('[' + nickname + '] guess -> ' + word);
    send('input', { action: 'guess', x: -1, y: -1, text: word });
  }, 1000);
}

ws.addEventListener('close', () => {
  console.log('[' + nickname + '] closed');
  process.exit(0);
});

ws.addEventListener('error', () => {
  console.log('[' + nickname + '] socket error');
});
