#!/usr/bin/env node
/**
 * 无头联机测试客户端。
 * 没有第二台设备时，用它冒充一个加入方，验证房主服务器的握手与成员广播。
 *
 * 用法：
 *   node tools/headless-client.mjs [url] [昵称]
 *   node tools/headless-client.mjs ws://127.0.0.1:8080 学生A
 *
 * 依赖 Node 22+ 内置的 WebSocket（无需 npm install）。
 */

const url = process.argv[2] ?? 'ws://127.0.0.1:8080';
const nickname = process.argv[3] ?? 'Bot';
const PROTOCOL_VERSION = 1;

let seq = 0;
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
  console.log('[' + nickname + '] <- ' + env.t + ' ' + JSON.stringify(body));
  if (env.t === 'error') {
    console.log('[' + nickname + '] rejected: ' + body.code);
    process.exit(3);
  }
});

ws.addEventListener('close', () => {
  console.log('[' + nickname + '] closed');
  process.exit(0);
});

ws.addEventListener('error', () => {
  console.log('[' + nickname + '] socket error');
});
