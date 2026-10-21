import {
  Building2,
  Church,
  GraduationCap,
  Hospital,
  Landmark,
  MapPin,
  Plane,
  ShieldCheck,
  Ship,
  Trophy,
  type LucideIcon,
} from "lucide-react";
import type { MapIconKey } from "./types";

export interface MapIconOption {
  key: MapIconKey;
  label: string;
  icon: LucideIcon;
}

export const mapIconOptions: MapIconOption[] = [
  { key: "government", label: "Cơ quan", icon: Building2 },
  { key: "place", label: "Địa điểm", icon: MapPin },
  { key: "tourism", label: "Du lịch", icon: Landmark },
  { key: "temple", label: "Đền chùa", icon: Church },
  { key: "police", label: "Công an", icon: ShieldCheck },
  { key: "stadium", label: "Sân vận động", icon: Trophy },
  { key: "hospital", label: "Bệnh viện", icon: Hospital },
  { key: "school", label: "Trường học", icon: GraduationCap },
  { key: "airport", label: "Sân bay", icon: Plane },
  { key: "port", label: "Cảng", icon: Ship },
];

export const mapIconByKey = Object.fromEntries(
  mapIconOptions.map((option) => [option.key, option]),
) as Record<MapIconKey, MapIconOption>;
