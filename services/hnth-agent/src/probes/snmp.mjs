import dgram from "node:dgram";
import { numeric } from "../util.mjs";

// Mã hóa BER tối thiểu cho một GetRequest SNMP v2c (một OID), không cần thư viện.
export function berLength(length) { return length < 128 ? Buffer.from([length]) : Buffer.from([0x81, length]); }
export function ber(type, value) { return Buffer.concat([Buffer.from([type]), berLength(value.length), value]); }
export function berInteger(value) { const out = Buffer.alloc(4); out.writeInt32BE(value); return ber(0x02, out.subarray(out.findIndex((byte) => byte !== 0) < 0 ? 3 : out.findIndex((byte) => byte !== 0))); }
export function berOid(oid) { const parts = oid.split(".").map(Number); const bytes = [parts[0] * 40 + parts[1]]; for (const part of parts.slice(2)) { const stack = [part & 0x7f]; let rest = part >>> 7; while (rest) { stack.unshift((rest & 0x7f) | 0x80); rest >>>= 7; } bytes.push(...stack); } return ber(0x06, Buffer.from(bytes)); }
export function readBer(buffer, offset = 0) { const type = buffer[offset]; let length = buffer[offset + 1]; let cursor = offset + 2; if (length & 0x80) { const count = length & 0x7f; length = 0; for (let i = 0; i < count; i += 1) length = length * 256 + buffer[cursor++]; } return { type, start: offset, valueStart: cursor, end: cursor + length, value: buffer.subarray(cursor, cursor + length) }; }
export function collectBer(buffer, output = []) { let offset = 0; while (offset + 2 <= buffer.length) { const item = readBer(buffer, offset); output.push(item); if (item.type & 0x20) collectBer(item.value, output); offset = item.end; } return output; }
export function snmpPacket(community, oid, requestId) { const variable = ber(0x30, Buffer.concat([berOid(oid), ber(0x05, Buffer.alloc(0))])); const pdu = ber(0xa0, Buffer.concat([berInteger(requestId), berInteger(0), berInteger(0), ber(0x30, variable)])); return ber(0x30, Buffer.concat([berInteger(1), ber(0x04, Buffer.from(community)), pdu])); }

// Lấy giá trị cuối cùng không phải cấu trúc/INTEGER/OCTET STRING/OID; nếu không có
// (giá trị là OCTET STRING) thì lấy OCTET STRING đầu tiên khác community.
export function parseSnmpResponse(message, community) {
  const items = collectBer(message);
  const value = items.reverse().find((item) => ![0x30, 0xa0, 0xa2, 0x02, 0x04, 0x06].includes(item.type));
  const fallback = items.find((item) => item.type === 0x04 && item.value.toString() !== String(community || "public"));
  return { value: (value || fallback)?.value?.toString("utf8") || "", valueType: value?.type ? `0x${value.type.toString(16)}` : "unknown" };
}

export async function snmpGet(target, oid, defaultTimeoutMs) {
  return new Promise((resolve, reject) => {
    const socket = dgram.createSocket("udp4");
    const requestId = Math.floor(Math.random() * 2_000_000_000);
    const timer = setTimeout(() => { socket.close(); reject(new Error("SNMP timeout")); }, numeric(target.timeoutMs ?? defaultTimeoutMs, 1500, 200, 10000));
    socket.on("message", (message) => { clearTimeout(timer); socket.close(); resolve(parseSnmpResponse(message, target.community)); });
    socket.send(snmpPacket(target.community || "public", oid, requestId), Number(target.port || 161), target.host, (error) => { if (error) { clearTimeout(timer); socket.close(); reject(error); } });
  });
}

export async function collectSnmp(config) {
  const rows = [];
  for (const target of Array.isArray(config.snmpTargets) ? config.snmpTargets : []) {
    for (const oid of Array.isArray(target.oids) ? target.oids : []) {
      try {
        const result = await snmpGet(target, oid, config.snmpTimeoutMs);
        rows.push({ targetId: target.targetId || target.host, host: target.host, oid, ...result, checkedAt: new Date().toISOString() });
      } catch (error) {
        rows.push({ targetId: target.targetId || target.host, host: target.host, oid, value: null, valueType: "error", error: error.message, checkedAt: new Date().toISOString() });
      }
    }
  }
  return rows;
}
