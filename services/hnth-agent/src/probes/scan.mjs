import { exec, numeric, sleep } from "../util.mjs";
import { pingHost } from "./ping.mjs";

export function expandSubnet(cidr) {
  const [base, prefixText] = cidr.split("/");
  const prefix = Number(prefixText);
  if (prefix < 24 || prefix > 30) throw new Error(`Only /24-/30 scan subnets are supported: ${cidr}`);
  const octets = base.split(".").map(Number);
  const size = 2 ** (32 - prefix);
  const hostCount = Math.max(1, size - 2);
  const start = octets[3] & (256 - size);
  return Array.from({ length: hostCount }, (_, index) => `${octets[0]}.${octets[1]}.${octets[2]}.${start + index + 1}`);
}

// Nhận diện Vendor ở mức OUI từ MAC lấy được trong ARP cache. Đây là thông tin
// bổ trợ; nếu thiết bị không có trong bảng OUI thì vẫn gửi IP/MAC bình thường.
const VENDORS = {
  "00000C": "Cisco",
  "001A2B": "Cisco",
  "001B54": "Cisco",
  "0026CB": "Cisco",
  "001C23": "Dell",
  "001E4F": "Dell",
  "0023AE": "Dell",
  "3C2C30": "Dell",
  "00155D": "Microsoft Hyper-V",
  "001C42": "Parallels",
  "005056": "VMware",
  "000569": "VMware",
  "001C14": "VMware",
  "001B21": "Intel",
  "3C970E": "Intel",
  "001E68": "Hewlett-Packard",
  "3C4A92": "Hewlett-Packard",
  "001E67": "Lenovo",
  "F8BC12": "Lenovo",
  "00184D": "Netgear",
  "001F33": "Netgear",
  "001A11": "Google",
  "B827EB": "Raspberry Pi",
  "DC4A3E": "Raspberry Pi",
  "001B63": "Cisco-Linksys",
  "00259C": "Cisco-Linksys",
  "0017F2": "Apple",
  "3C0754": "Apple",
  "ACDE48": "Apple",
  "0013D4": "Polycom",
  "64167F": "Poly",
  "001565": "Yealink"
};
export function vendorFromMac(macAddress) {
  const oui = macAddress.replace(/[:-]/g, "").slice(0, 6);
  return VENDORS[oui] || "";
}

async function networkIdentity(ipAddress) {
  if (process.platform !== "win32") return {};
  try {
    const { stdout } = await exec("arp.exe", ["-a", ipAddress], { windowsHide: true });
    const match = stdout.match(/\b([0-9a-f]{2}(?:-[0-9a-f]{2}){5})\b/i);
    if (!match) return {};
    const macAddress = match[1].toUpperCase();
    const modelVendor = vendorFromMac(macAddress);
    return { macAddress, ...(modelVendor ? { modelVendor } : {}) };
  } catch { return {}; }
}

/** Ping quét các subnet theo lô, trả các IP trả lời kèm MAC/vendor từ ARP. */
export async function discoverHosts(scanSubnets, config) {
  const targets = scanSubnets.flatMap(expandSubnet);
  const ips = [];
  const concurrency = numeric(config.scanConcurrency, 32, 1, 128);
  const delayMs = numeric(config.scanDelayMs, 0, 0, 60000);
  for (let offset = 0; offset < targets.length; offset += concurrency) {
    const batch = targets.slice(offset, offset + concurrency);
    const results = await Promise.all(batch.map(async (ipAddress) => {
      try {
        await pingHost(ipAddress, 500);
        return { ipAddress, status: "online", ...(await networkIdentity(ipAddress)), discoveredAt: new Date().toISOString() };
      } catch { return null; }
    }));
    ips.push(...results.filter(Boolean));
    if (delayMs && offset + concurrency < targets.length) await sleep(delayMs);
  }
  return ips;
}
