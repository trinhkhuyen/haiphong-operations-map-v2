import { describe, expect, it } from "vitest";
import type { StoreApi } from "zustand";
import { createAdministrativeSlice } from "./administrative";
import { createAnnotationsSlice } from "./annotations";
import { createDrawingSlice } from "./drawing";
import { createHnthSlice } from "./hnth";
import { createLayersSlice } from "./layers";
import { createMapSlice } from "./map";
import type { AppSlice, AppState } from "./types";
import { createUiSlice } from "./ui";

const creators: Record<string, AppSlice<object>> = {
  ui: createUiSlice, layers: createLayersSlice, map: createMapSlice, administrative: createAdministrativeSlice,
  drawing: createDrawingSlice, annotations: createAnnotationsSlice, hnth: createHnthSlice,
};

describe("store slices", () => {
  it("không slice nào trùng khóa (spread sẽ âm thầm ghi đè) và đủ 115 trường (113 của store một khối cũ + hnthTransparentPopups và setter)", () => {
    const api = { setState: () => undefined, getState: () => ({}) as AppState } as unknown as Parameters<AppSlice<object>>[2];
    const owner = new Map<string, string>();
    for (const [name, create] of Object.entries(creators)) {
      for (const key of Object.keys(create(api.setState as StoreApi<AppState>["setState"], api.getState, api))) {
        expect(owner.get(key), `${key} có ở cả ${owner.get(key)} và ${name}`).toBeUndefined();
        owner.set(key, name);
      }
    }
    expect(owner.size).toBe(115);
  });
});
