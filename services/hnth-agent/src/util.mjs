import { execFile } from "node:child_process";
import { promisify } from "node:util";

export const exec = promisify(execFile);
export const numeric = (value, fallback, min, max) => Math.max(min, Math.min(max, Number.isFinite(Number(value)) ? Number(value) : fallback));
export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
