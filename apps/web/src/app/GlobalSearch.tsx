import { useEffect, useMemo, useRef, useState } from "react";
import { Search } from "lucide-react";
import { useAppStore } from "../core/store";
import { searchHaiphongPlaces, type PlaceSearchResult } from "../features/search/geocoding-provider";
import { HNTH_LAYER_ID } from "../features/layers/hnth-data-provider";
import { emitAppEvent } from "../core/events";
import { focusHnthPoint, normalizeSearchText } from "../features/conference/hnth-focus";
import type { HnthPointFeature } from "../features/conference/hnth-types";

const HNTH_SEARCH_LIMIT = 20;

/**
 * Ô tìm kiếm trên thanh tiêu đề. Ở menu HNTH chỉ tìm điểm cầu (tên điểm, tên
 * xã/phường hoặc IP) ngay khi gõ, chọn bằng phím lên/xuống + Enter; phím F
 * đưa con trỏ vào ô. Các menu khác giữ tìm địa điểm toàn cục (Enter để tìm).
 */
export function GlobalSearch() {
  const [searchResults, setSearchResults] = useState<PlaceSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchError, setSearchError] = useState("");
  const [activeIndex, setActiveIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const setSearch = useAppStore((state) => state.setSearch);
  const searchValue = useAppStore((state) => state.search);
  const activePanel = useAppStore((state) => state.activePanel);
  const hnthMode = activePanel === "conference";
  const cameraMode = activePanel === "camera";
  const cameraDevices = useAppStore((state) => state.cameraDevices);
  const hnthLayer = useAppStore((state) => state.layers.find((item) => item.id === HNTH_LAYER_ID));
  const administrativeUnits = useAppStore((state) => state.administrativeUnits);

  useEffect(() => { setSearch(""); setSearchOpen(false); }, [activePanel, setSearch]);

  const hnthResults = useMemo(() => {
    const query = normalizeSearchText(searchValue);
    if (!hnthMode || !query) return [];
    const wardNames = new Map(administrativeUnits.map((unit) => [String(unit.wardCode ?? ""), `${unit.type} ${unit.name}`]));
    return (hnthLayer?.data.features ?? [])
      .filter((item): item is HnthPointFeature => item.geometry.type === "Point")
      .map((item) => {
        const name = String(item.properties?.name ?? "");
        const ipAddress = String(item.properties?.ipAddress ?? "");
        const ward = wardNames.get(String(item.properties?.wardCode ?? "")) ?? "";
        return { item, name, ipAddress, ward, text: normalizeSearchText(`${name} ${ward} ${ipAddress}`) };
      })
      .filter((entry) => entry.text.includes(query))
      .slice(0, HNTH_SEARCH_LIMIT);
  }, [hnthMode, searchValue, hnthLayer, administrativeUnits]);

  const cameraResults = useMemo(() => {
    const query = normalizeSearchText(searchValue);
    if (!cameraMode || !query) return [];
    return cameraDevices.filter((device) => normalizeSearchText(`${device.name} ${device.serialNumber} ${device.ipAddress || ""} ${device.model || ""} ${Object.values(device.channelNames || {}).join(" ")} ${(device.channelStates || []).map((channel) => channel.name || "").join(" ")}`).includes(query)).slice(0, HNTH_SEARCH_LIMIT);
  }, [cameraDevices, cameraMode, searchValue]);

  useEffect(() => setActiveIndex(0), [searchValue, hnthMode, cameraMode]);
  // Giữ dòng đang chọn bằng phím lên/xuống luôn nằm trong khung gợi ý.
  useEffect(() => { document.querySelector(".global-search-results button.is-active")?.scrollIntoView({ block: "nearest" }); }, [activeIndex]);

  // Phím F (không phải khi đang gõ ở ô khác) đưa con trỏ vào ô tìm kiếm ở menu HNTH/Camera.
  useEffect(() => {
    if (!hnthMode && !cameraMode) return;
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (event.key.toLowerCase() !== "f" || event.ctrlKey || event.metaKey || event.altKey) return;
      if (target?.isContentEditable || target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || target?.tagName === "SELECT") return;
      event.preventDefault();
      inputRef.current?.focus();
      inputRef.current?.select();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [hnthMode, cameraMode]);

  // Esc ở menu HNTH/Camera: đóng gợi ý tìm kiếm và toàn bộ popup nghiệp vụ của menu.
  useEffect(() => {
    if (!hnthMode && !cameraMode) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      setSearch("");
      setSearchOpen(false);
      inputRef.current?.blur();
      if (cameraMode) emitAppEvent("camera:close-overlays");
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [hnthMode, cameraMode, setSearch]);

  const runGlobalSearch = async () => {
    const query = searchValue.trim();
    if (!query) { setSearchResults([]); setSearchOpen(false); return; }
    setSearching(true); setSearchError(""); setSearchOpen(true);
    try {
      setSearchResults(await searchHaiphongPlaces(query));
    } catch (error) {
      if ((error as DOMException)?.name !== "AbortError") setSearchError(error instanceof Error ? error.message : "Không tìm được địa điểm");
    } finally { setSearching(false); }
  };

  const chooseHnth = (index: number) => {
    const entry = hnthResults[index];
    if (!entry) return;
    // Về Home trước (như phím 0 lần lẻ) rồi mới khoanh vùng và chạy hiệu ứng viền.
    emitAppEvent("map:go-home", { then: () => focusHnthPoint(entry.item) });
    setSearchOpen(false);
    inputRef.current?.blur();
  };

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Escape") { setSearchOpen(false); inputRef.current?.blur(); if (cameraMode) emitAppEvent("camera:close-overlays"); return; }
    if (cameraMode) {
      if (event.key === "Enter") { event.preventDefault(); const device = cameraResults[activeIndex]; if (device) { useAppStore.getState().selectCamera(device.id); emitAppEvent("camera:expand", { deviceId: device.id }); emitAppEvent("map:context-info", { kind: "camera", deviceId: device.id }); setSearchOpen(false); inputRef.current?.blur(); } }
      return;
    }
    if (!hnthMode) {
      if (event.key === "Enter") { event.preventDefault(); void runGlobalSearch(); }
      return;
    }
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      setSearchOpen(true);
      const count = hnthResults.length;
      if (count) setActiveIndex((index) => (index + (event.key === "ArrowDown" ? 1 : count - 1)) % count);
    }
    if (event.key === "Enter") { event.preventDefault(); chooseHnth(activeIndex); }
  };

  const showHnth = hnthMode && searchOpen && searchValue.trim() !== "";
  const showCamera = cameraMode && searchOpen && searchValue.trim() !== "";
  return <div className={`global-search${searchOpen ? " is-open" : ""}`}>
    <Search size={18}/>
    <input
      ref={inputRef}
      value={searchValue}
      onChange={(event) => { setSearch(event.target.value); setSearchOpen(hnthMode || cameraMode); }}
      onKeyDown={onKeyDown}
      onFocus={() => { if (hnthMode ? searchValue.trim() : cameraMode ? searchValue.trim() : searchResults.length || searchError) setSearchOpen(true); }}
      onBlur={() => { if (hnthMode) window.setTimeout(() => setSearchOpen(false), 150); }}
      placeholder={hnthMode ? "Tìm điểm cầu: tên, xã/phường, IP… (phím F)" : cameraMode ? "Tìm đầu ghi, tên camera, IP…" : "Tìm địa điểm, camera, cơ quan..."}
      aria-label={hnthMode ? "Tìm điểm cầu HNTH" : cameraMode ? "Tìm đầu ghi hoặc camera" : "Tìm địa điểm, camera, cơ quan"}
    />
    <button className="global-search-submit" type="button" onClick={() => hnthMode ? chooseHnth(activeIndex) : cameraMode ? (() => { const device = cameraResults[activeIndex]; if (device) { useAppStore.getState().selectCamera(device.id); emitAppEvent("camera:expand", { deviceId: device.id }); emitAppEvent("map:context-info", { kind: "camera", deviceId: device.id }); setSearchOpen(false); } })() : void runGlobalSearch()} aria-label="Tìm kiếm"><Search size={15}/></button>
    <kbd>{hnthMode ? "F" : "⌘ K"}</kbd>
    {showHnth && <div className="global-search-results" role="listbox">
      {hnthResults.length === 0 && <p>Không có điểm cầu phù hợp.</p>}
      {hnthResults.map((entry, index) => <button key={String(entry.item.properties?.pointId ?? entry.item.id)} type="button" role="option" aria-selected={index === activeIndex} className={index === activeIndex ? "is-active" : ""} onMouseEnter={() => setActiveIndex(index)} onMouseDown={(event) => event.preventDefault()} onClick={() => chooseHnth(index)}>
        <strong>{entry.name}</strong><small>{[entry.ward, entry.ipAddress || "Chưa có IP"].filter(Boolean).join(" · ")}</small>
      </button>)}
    </div>}
    {showCamera && <div className="global-search-results">
      {cameraResults.length === 0 && <p>Không có đầu ghi hoặc camera phù hợp.</p>}
      {cameraResults.map((device, index) => <button key={device.id} type="button" className={index === activeIndex ? "is-active" : ""} onMouseEnter={() => setActiveIndex(index)} onMouseDown={(event) => event.preventDefault()} onClick={() => { useAppStore.getState().selectCamera(device.id); emitAppEvent("camera:expand", { deviceId: device.id }); emitAppEvent("map:context-info", { kind: "camera", deviceId: device.id }); setSearchOpen(false); inputRef.current?.blur(); }}><strong>{device.name}</strong><small>{[device.ipAddress || "Chưa có IP", Array.from(new Set([...Object.values(device.channelNames || {}), ...(device.channelStates || []).map((channel) => channel.name || "")])).filter(Boolean).join(", ")].filter(Boolean).join(" · ")}</small></button>)}
    </div>}
    {!hnthMode && !cameraMode && searchOpen && <div className="global-search-results">
      {searching && <p>Đang tìm kiếm…</p>}
      {!searching && searchError && <p className="error">Không thể tìm kiếm lúc này.</p>}
      {!searching && !searchError && searchResults.length === 0 && <p>Không có kết quả phù hợp.</p>}
      {!searching && searchResults.map((place) => <button key={place.id} type="button" onClick={() => { useAppStore.getState().setDrawSearchTarget(place); setSearchOpen(false); }}><strong>{place.name}</strong><small>{place.category} · {place.detail}</small></button>)}
    </div>}
  </div>;
}
