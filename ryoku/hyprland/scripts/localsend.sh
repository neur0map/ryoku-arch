#!/bin/bash
# LocalSend helper for the Ryoku shell file stash: LAN device discovery and send.
# Usage: localsend.sh discover | send <file> <target-ip>
set -u
cmd="${1:-}"
case "$cmd" in
discover)
  python3 - <<'PYEOF'
import socket, json, time, struct, re, subprocess, asyncio, ssl
MCAST='224.0.0.167'; PORT=53317
out=subprocess.check_output(["ip","-4","addr"],text=True)
local_ips=set(re.findall(r'inet (\d+\.\d+\.\d+\.\d+)',out))
route_out=subprocess.check_output(["ip","route","get",MCAST],text=True)
src_m=re.search(r'src (\d+\.\d+\.\d+\.\d+)',route_out)
lan_ip=src_m.group(1) if src_m else ''
seen=set()
def emit(ip,alias):
    if ip not in seen and ip not in local_ips:
        seen.add(ip); print(f"{alias}\t{ip}",flush=True)
rx=socket.socket(socket.AF_INET,socket.SOCK_DGRAM,socket.IPPROTO_UDP)
rx.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
rx.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEPORT,1)
rx.bind(('',PORT))
mreq=(struct.pack('4s4s',socket.inet_aton(MCAST),socket.inet_aton(lan_ip)) if lan_ip else struct.pack('4sL',socket.inet_aton(MCAST),socket.INADDR_ANY))
rx.setsockopt(socket.IPPROTO_IP,socket.IP_ADD_MEMBERSHIP,mreq); rx.settimeout(0.1)
tx=socket.socket(socket.AF_INET,socket.SOCK_DGRAM,socket.IPPROTO_UDP)
tx.setsockopt(socket.IPPROTO_IP,socket.IP_MULTICAST_TTL,4)
if lan_ip: tx.setsockopt(socket.IPPROTO_IP,socket.IP_MULTICAST_IF,socket.inet_aton(lan_ip))
announce=json.dumps({"alias":"Ryoku Stash","version":"2.1","deviceModel":None,"deviceType":"headless","fingerprint":"ryoku_stash_discover","port":PORT,"protocol":"https","download":False,"announce":True}).encode()
tx.sendto(announce,(MCAST,PORT)); deadline=time.time()+2.0; sent_second=False
while time.time()<deadline:
    if not sent_second and time.time()>deadline-1.0:
        tx.sendto(announce,(MCAST,PORT)); sent_second=True
    try:
        data,(ip,_)=rx.recvfrom(65536)
        if ip in local_ips: continue
        try: info=json.loads(data.decode())
        except Exception: continue
        if info.get('fingerprint')=='ryoku_stash_discover': continue
        emit(ip,info.get('alias','Unknown'))
    except socket.timeout: pass
if not lan_ip:
    import sys; sys.exit(0)
prefix='.'.join(lan_ip.split('.')[:3])
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
async def probe(ip):
    if ip in local_ips or ip in seen: return
    try:
        r,w=await asyncio.wait_for(asyncio.open_connection(ip,PORT,ssl=ctx),timeout=0.6)
        w.write(f"GET /api/localsend/v2/info HTTP/1.0\r\nHost: {ip}\r\nConnection: close\r\n\r\n".encode())
        await w.drain()
        data=await asyncio.wait_for(r.read(4096),timeout=0.6); w.close()
        body=data.split(b'\r\n\r\n',1)
        if len(body)<2: return
        info=json.loads(body[1].decode()); emit(ip,info.get('alias','Unknown'))
    except Exception: pass
async def scan():
    await asyncio.gather(*[probe(f"{prefix}.{i}") for i in range(1,255)])
asyncio.run(scan())
PYEOF
  ;;
send)
  FILE="$2"; TARGET="$3"
  [ -f "$FILE" ] || { notify-send "LocalSend" "File not found" -i dialog-error; exit 1; }
  [ -n "$TARGET" ] || { notify-send "LocalSend" "No target device" -i dialog-error; exit 1; }
  PORT=53317; FILENAME=$(basename "$FILE"); FILESIZE=$(stat -c%s "$FILE"); FILETYPE=$(file -b --mime-type "$FILE"); FILE_ID="qs_$(date +%s%N | md5sum | head -c8)"
  FP_FILE="$HOME/.cache/ryoku_localsend_fp"; [ -f "$FP_FILE" ] || openssl rand -hex 16 > "$FP_FILE"; FINGERPRINT=$(cat "$FP_FILE")
  BODY=$(python3 - "$FILENAME" "$FILESIZE" "$FILETYPE" "$FILE_ID" "$FINGERPRINT" "$PORT" <<'PYEOF'
import json,sys
fn,sz,ft,fid,fp,port=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4],sys.argv[5],int(sys.argv[6])
print(json.dumps({"info":{"alias":"Ryoku Stash","version":"2.1","deviceModel":None,"deviceType":"headless","fingerprint":fp,"port":port,"protocol":"https","download":False},"files":{fid:{"id":fid,"fileName":fn,"size":sz,"fileType":ft,"sha256":None,"preview":None,"metadata":None}}}))
PYEOF
)
  RESP=$(curl -sk --max-time 30 -X POST "https://$TARGET:$PORT/api/localsend/v2/prepare-upload" -H "Content-Type: application/json" -d "$BODY")
  SESSION=$(python3 -c "import sys,json; print(json.loads(sys.argv[1]).get('sessionId',''))" "$RESP" 2>/dev/null)
  TOKEN=$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('files',{}).get('$FILE_ID',''))" "$RESP" 2>/dev/null)
  [ -n "$SESSION" ] && [ -n "$TOKEN" ] || { notify-send "LocalSend" "Rejected or timed out" -i dialog-error; exit 1; }
  curl -sk --max-time 120 -X POST "https://$TARGET:$PORT/api/localsend/v2/upload?sessionId=$SESSION&fileId=$FILE_ID&token=$TOKEN" -H "Content-Type: $FILETYPE" --data-binary @"$FILE" >/dev/null && notify-send "LocalSend" "Sent: $FILENAME" -i emblem-ok-symbolic || notify-send "LocalSend" "Upload failed" -i dialog-error
  ;;
*) echo "usage: localsend.sh discover | send <file> <ip>" >&2; exit 2 ;;
esac
