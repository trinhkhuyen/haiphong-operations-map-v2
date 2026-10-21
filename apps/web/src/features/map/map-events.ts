// Thẻ thông tin cố định trên bản đồ (detail của sự kiện "map:context-info",
// xem AppEventMap trong core/events.ts).
export type FixedMapInfo =
  | { kind: "administrative"; unitId: number; includeConnectionPoint: boolean }
  | { kind: "hnth"; pointId: string; administrativeId?: number; pulseBoundary?: boolean };
