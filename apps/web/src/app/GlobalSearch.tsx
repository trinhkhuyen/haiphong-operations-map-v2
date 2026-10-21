import { useState } from "react";
import { Search } from "lucide-react";
import { useAppStore } from "../core/store";
import { searchHaiphongPlaces, type PlaceSearchResult } from "../features/search/geocoding-provider";

/** Ô tìm địa điểm trên thanh tiêu đề; chọn kết quả thì bản đồ bay tới đó. */
export function GlobalSearch() {
  const [searchResults, setSearchResults] = useState<PlaceSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchError, setSearchError] = useState("");
  const setSearch = useAppStore((state) => state.setSearch);
  const searchValue = useAppStore((state) => state.search);

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

  return <div className={`global-search${searchOpen ? " is-open" : ""}`}>
    <Search size={18}/>
    <input value={searchValue} onChange={(event) => { setSearch(event.target.value); setSearchOpen(false); }} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); void runGlobalSearch(); } if (event.key === "Escape") setSearchOpen(false); }} onFocus={() => { if (searchResults.length || searchError) setSearchOpen(true); }} placeholder="Tìm địa điểm, camera, cơ quan..." aria-label="Tìm địa điểm, camera, cơ quan" />
    <button className="global-search-submit" type="button" onClick={() => void runGlobalSearch()} aria-label="Tìm kiếm"><Search size={15}/></button>
    <kbd>⌘ K</kbd>
    {searchOpen && <div className="global-search-results">
      {searching && <p>Đang tìm kiếm…</p>}
      {!searching && searchError && <p className="error">Không thể tìm kiếm lúc này.</p>}
      {!searching && !searchError && searchResults.length === 0 && <p>Không có kết quả phù hợp.</p>}
      {!searching && searchResults.map((place) => <button key={place.id} type="button" onClick={() => { useAppStore.getState().setDrawSearchTarget(place); setSearchOpen(false); }}><strong>{place.name}</strong><small>{place.category} · {place.detail}</small></button>)}
    </div>}
  </div>;
}
