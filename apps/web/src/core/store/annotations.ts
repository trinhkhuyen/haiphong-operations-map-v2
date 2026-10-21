// Nhãn chữ/biểu tượng và thao tác chung cho Đối tượng đã lưu (hình, nhãn, biểu tượng).
import type { IconAnnotation, MapIconKey, SavedObjectKind, TextAnnotation } from "../types";
import type { AppSlice } from "./types";

export interface AnnotationsSlice {
  textDraft: string;
  textAnnotations: TextAnnotation[];
  iconDraft: MapIconKey;
  iconAnnotations: IconAnnotation[];
  selectedAnnotation: { kind: "text" | "icon"; id: string } | null;
  focusSavedObjectRequest: { kind: SavedObjectKind; id: string; request: number } | null;
  setTextDraft: (value: string) => void;
  addTextAnnotation: (coordinates: [number, number]) => void;
  setIconDraft: (icon: MapIconKey) => void;
  addIconAnnotation: (coordinates: [number, number]) => void;
  selectAnnotation: (kind: "text" | "icon", id: string) => void;
  updateSelectedAnnotationText: (text: string) => void;
  updateSelectedAnnotationIcon: (icon: MapIconKey) => void;
  updateSelectedAnnotationColor: (color: string) => void;
  moveAnnotation: (kind: "text" | "icon", id: string, coordinates: [number, number]) => void;
  deleteSelectedAnnotation: () => void;
  clearSelectedAnnotation: () => void;
  saveSelectedObject: (name: string) => void;
  toggleSavedObject: (kind: SavedObjectKind, id: string) => void;
  renameSavedObject: (kind: SavedObjectKind, id: string, name: string) => void;
  deleteSavedObject: (kind: SavedObjectKind, id: string) => void;
  requestFocusSavedObject: (kind: SavedObjectKind, id: string) => void;
}

export const createAnnotationsSlice: AppSlice<AnnotationsSlice> = (set) => ({
  textDraft: "Nhãn mới",
  textAnnotations: [],
  iconDraft: "place",
  iconAnnotations: [],
  selectedAnnotation: null,
  focusSavedObjectRequest: null,
  setTextDraft: (textDraft) => set({ textDraft }),
  addTextAnnotation: (coordinates) => set((state) => {
    const text = state.textDraft.trim();
    if (!text) return state;
    return {
      textAnnotations: [...state.textAnnotations, {
        id: `text-${Date.now()}-${state.textAnnotations.length}`,
        text,
        coordinates,
        color: state.drawOutlineColor,
        visible: true,
        saved: false,
      }],
      drawMode: "select",
    };
  }),
  setIconDraft: (iconDraft) => set({ iconDraft }),
  addIconAnnotation: (coordinates) => set((state) => ({
    iconAnnotations: [...state.iconAnnotations, {
      id: `icon-${Date.now()}-${state.iconAnnotations.length}`,
      icon: state.iconDraft,
      coordinates,
      color: state.drawOutlineColor,
      visible: true,
      saved: false,
    }],
    drawMode: "select",
  })),
  selectAnnotation: (kind, id) => set({ selectedAnnotation: { kind, id }, selectedDrawFeatureId: null, selectedDrawFeatureInfo: null, zoneMode: "draw", drawMode: "select" }),
  updateSelectedAnnotationText: (text) => set((state) => state.selectedAnnotation?.kind === "text" ? ({
    textAnnotations: state.textAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, text } : annotation),
  }) : state),
  updateSelectedAnnotationIcon: (icon) => set((state) => state.selectedAnnotation?.kind === "icon" ? ({
    iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, icon } : annotation),
  }) : state),
  updateSelectedAnnotationColor: (color) => set((state) => {
    if (!state.selectedAnnotation) return state;
    return state.selectedAnnotation.kind === "text"
      ? { textAnnotations: state.textAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, color } : annotation) }
      : { iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === state.selectedAnnotation?.id ? { ...annotation, color } : annotation) };
  }),
  moveAnnotation: (kind, id, coordinates) => set((state) => kind === "text" ? ({
    textAnnotations: state.textAnnotations.map((annotation) => annotation.id === id ? { ...annotation, coordinates } : annotation),
  }) : ({
    iconAnnotations: state.iconAnnotations.map((annotation) => annotation.id === id ? { ...annotation, coordinates } : annotation),
  })),
  deleteSelectedAnnotation: () => set((state) => {
    if (!state.selectedAnnotation) return state;
    return state.selectedAnnotation.kind === "text"
      ? { textAnnotations: state.textAnnotations.filter((annotation) => annotation.id !== state.selectedAnnotation?.id), selectedAnnotation: null }
      : { iconAnnotations: state.iconAnnotations.filter((annotation) => annotation.id !== state.selectedAnnotation?.id), selectedAnnotation: null };
  }),
  clearSelectedAnnotation: () => set({ selectedAnnotation: null }),
  saveSelectedObject: (rawName) => set((state) => {
    const name = rawName.trim() || "Đối tượng chưa đặt tên";
    if (state.selectedAnnotation?.kind === "text") {
      return {
        textAnnotations: state.textAnnotations.map((item) => item.id === state.selectedAnnotation?.id
          ? { ...item, name, saved: true, visible: true }
          : item),
      };
    }
    if (state.selectedAnnotation?.kind === "icon") {
      return {
        iconAnnotations: state.iconAnnotations.map((item) => item.id === state.selectedAnnotation?.id
          ? { ...item, name, saved: true, visible: true }
          : item),
      };
    }
    if (state.selectedDrawFeatureId === null) return state;
    return {
      saveSelectedObjectRequest: {
        name,
        request: (state.saveSelectedObjectRequest?.request ?? 0) + 1,
      },
    };
  }),
  toggleSavedObject: (kind, id) => set((state) => {
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.map((item) => item.id === id ? { ...item, visible: !item.visible } : item) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.map((item) => item.id === id ? { ...item, visible: item.visible === false } : item) };
    return { iconAnnotations: state.iconAnnotations.map((item) => item.id === id ? { ...item, visible: item.visible === false } : item) };
  }),
  renameSavedObject: (kind, id, rawName) => set((state) => {
    const name = rawName.trim();
    if (!name) return state;
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.map((item) => item.id === id ? { ...item, name } : item) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.map((item) => item.id === id ? { ...item, name } : item) };
    return { iconAnnotations: state.iconAnnotations.map((item) => item.id === id ? { ...item, name } : item) };
  }),
  deleteSavedObject: (kind, id) => set((state) => {
    if (kind === "geometry") return { savedDrawFeatures: state.savedDrawFeatures.filter((item) => item.id !== id) };
    if (kind === "text") return { textAnnotations: state.textAnnotations.filter((item) => item.id !== id), selectedAnnotation: state.selectedAnnotation?.id === id ? null : state.selectedAnnotation };
    return { iconAnnotations: state.iconAnnotations.filter((item) => item.id !== id), selectedAnnotation: state.selectedAnnotation?.id === id ? null : state.selectedAnnotation };
  }),
  requestFocusSavedObject: (kind, id) => set((state) => ({
    focusSavedObjectRequest: { kind, id, request: (state.focusSavedObjectRequest?.request ?? 0) + 1 },
    savedDrawFeatures: kind === "geometry" ? state.savedDrawFeatures.map((item) => item.id === id ? { ...item, visible: true } : item) : state.savedDrawFeatures,
    textAnnotations: kind === "text" ? state.textAnnotations.map((item) => item.id === id ? { ...item, visible: true } : item) : state.textAnnotations,
    iconAnnotations: kind === "icon" ? state.iconAnnotations.map((item) => item.id === id ? { ...item, visible: true } : item) : state.iconAnnotations,
  })),
});
