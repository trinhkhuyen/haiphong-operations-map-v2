import { downloadWorkbook, readFirstSheetRows } from "../../core/spreadsheet";
import type { UbndPoint } from "../administrative/data-provider";
import type { CameraDevice } from "../../core/store/camera";

export type CameraImportRow = Pick<CameraDevice, "name" | "serialNumber" | "username" | "password" | "ipAddress" | "vendor" | "model" | "devicePort" | "httpPort" | "streamPort" | "connectionMethod" | "autoConnect" | "administrativeId" | "longitude" | "latitude" | "channelStates"> & { channels: number | null };
const normalize = (value: string) => value.replace(/^\uFEFF/, "").trim().toLocaleLowerCase("vi").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[đĐ]/g, "d").replace(/[\s_/-]+/g, "");
const csv = (text: string) => text.trim().split(/\r?\n/).map((line) => line.split(",").map((cell) => cell.trim().replace(/^"|"$/g, "")));
function rowsToData(rows: string[][]): CameraImportRow[] {
  if (rows.length < 2) return [];
  const headers = rows[0].map(normalize);
  const index = (...names: string[]) => headers.findIndex((header) => names.includes(header));
  const get = (row: string[], names: string[]) => String(row[index(...names.map(normalize))] ?? "").trim();
  const nameIndex = index("tenthietbi", "tendiem", "name");
  if (nameIndex < 0) throw new Error("File Camera phải có cột Tên thiết bị");
  const numberOrNull = (value: string) => value === "" || !Number.isFinite(Number(value)) ? null : Number(value);
  const booleanOrFalse = (value: string) => /^(1|true|yes|y|co|có|on|x)$/i.test(value.trim());
  return rows.slice(1).map((row) => ({
    name: String(row[nameIndex] ?? "").trim(),
    serialNumber: get(row, ["map2p", "serialnumber", "sn", "cloudid"]),
    username: get(row, ["tendangnhap", "username"]) || "admin",
    password: get(row, ["matkhau", "password"]),
    ipAddress: get(row, ["diachilan", "ipaddress", "ip"]),
    vendor: get(row, ["hangadapter", "vendor", "hang"]),
    model: get(row, ["model", "modelthietbi"]),
    devicePort: numberOrNull(get(row, ["congthietbi", "congskd", "deviceport", "port"])) ?? 8000,
    httpPort: numberOrNull(get(row, ["conghttp", "httpport"])) ?? 80,
    streamPort: numberOrNull(get(row, ["congrtsp", "streamport", "rtspport"])) ?? 554,
    connectionMethod: get(row, ["phuongthucketnoi", "connectionmethod"]) || "auto",
    autoConnect: booleanOrFalse(get(row, ["tudongketnoi", "autoconnect", "automaticconnect"])),
    channels: numberOrNull(get(row, ["sokenhtudo", "sokenh", "channels"])),
    administrativeId: get(row, ["madiagioubnd", "madiagioi", "administrativeid"]) || null,
    longitude: numberOrNull(get(row, ["kinhdo", "longitude"])),
    latitude: numberOrNull(get(row, ["vido", "latitude"])),
    channelStates: headers.map((header, headerIndex) => /^tenkenh\d+$/.test(header) ? { id: Number(header.replace("tenkenh", "")), name: String(row[headerIndex] ?? "").trim(), online: true } : null).filter((item): item is { id: number; name: string; online: boolean } => Boolean(item && item.name)),
  })).filter((row) => row.name && (row.serialNumber || row.ipAddress));
}
export async function readCameraImportFile(file: File): Promise<CameraImportRow[]> {
  return file.name.toLocaleLowerCase().endsWith(".xlsx") ? rowsToData((await readFirstSheetRows(file)).map((row) => row.map(String))) : rowsToData(csv(await file.text()));
}
export async function exportCameraDevicesXlsx(devices: CameraDevice[], points: UbndPoint[]) {
  const channelCount = Math.max(0, ...devices.map((device) => Math.max(device.channels || 0, ...(device.channelStates || []).map((channel) => channel.id))));
  const header = ["Tên thiết bị", "Mã P2P / S/N", "Tên đăng nhập", "Mật khẩu", "Địa chỉ LAN", "Hãng / adapter", "Model", "Cổng SDK / thiết bị", "Cổng HTTP", "Cổng RTSP", "Phương thức kết nối", "Tự động kết nối", "Gán vào mốc UBND", "Mã mốc UBND", "Kinh độ", "Vĩ độ", "Số kênh (tự dò)", ...Array.from({ length: channelCount }, (_, index) => `Tên kênh ${index + 1}`)];
  const rows = devices.map((device) => [
    device.name,
    device.serialNumber,
    device.username,
    device.password,
    device.ipAddress ?? "",
    device.vendor ?? "",
    device.model ?? "",
    device.devicePort ?? 8000,
    device.httpPort ?? 80,
    device.streamPort ?? 554,
    device.connectionMethod ?? "auto",
    device.autoConnect ? "Có" : "Không",
    points.find((point) => point.wardCode === device.administrativeId)?.name ?? "Điểm ngoài danh sách mốc UBND",
    device.administrativeId ?? "",
    device.longitude ?? "",
    device.latitude ?? "",
    device.channels ?? "",
    ...Array.from({ length: channelCount }, (_, index) => {
      const deviceChannelCount = typeof device.channels === "number" && device.channels > 0
        ? device.channels
        : Math.max(0, ...(device.channelStates || []).map((channel) => channel.id));
      if (index >= deviceChannelCount) return "";
      const channel = device.channelStates?.find((item) => item.id === index + 1);
      const name = channel?.name?.trim() || `Kênh ${index + 1}`;
      const online = channel?.online === true || (!channel && device.status === "online" && index < (device.onlineChannels || 0));
      return `${name} (${online ? "online" : "offline"})`;
    }),
  ]);
  await downloadWorkbook(`camera-danh-sach-${new Date().toISOString().slice(0, 10)}.xlsx`, [{ name: "Danh sach Camera", rows: [header, ...rows], columnWidths: [28, 22, 18, 20, 16, 20, 18, 18, 14, 14, 20, 30, 14, 14, 14, 16, ...Array(channelCount).fill(20)], boldHeader: true }]);
}
