import { ping } from "./probes/ping.mjs";

// Ưu tiên điểm chưa có kết quả, sau đó điểm mất kết nối. Các điểm cùng
// nhóm vẫn được xoay vòng để không có endpoint nào bị cố định ở cuối.
export function orderCyclePoints(points, lastObservedStatuses, rotation) {
  const priority = (point) => {
    const status = lastObservedStatuses.get(point.pointId);
    return status === undefined ? 0 : status === "offline" ? 1 : 2;
  };
  const grouped = points.slice().sort((a, b) => priority(a) - priority(b));
  return grouped.length ? grouped.slice(rotation % grouped.length).concat(grouped.slice(0, rotation % grouped.length)) : grouped;
}

// Điểm trung tâm là endpoint bắt buộc của HNTH. Gửi lại điểm này ở mỗi
// vòng để không bị giữ "Chưa xác định" nếu frontend/backend vừa khởi
// động lại hoặc cache trạng thái cũ chưa đồng bộ.
export function resultsToSend(results, lastSentStatuses, sendAll) {
  return sendAll ? results : results.filter((item) => item.pointId === "hnth-hub" || lastSentStatuses.get(item.pointId) !== item.status);
}

/** Vòng Giám sát liên tục (monitor-start/stop, point-config). */
export function createMonitor({ config, client }) {
  let monitorTimer;
  let monitorRunId = 0;
  let monitorPoints = [];
  let monitorConcurrency = 1;
  let monitorWaitSeconds = 3;
  let monitorInitialCyclePending = false;
  let monitoringActive = false;
  const lastSentStatuses = new Map();
  const lastObservedStatuses = new Map();
  let monitorRotation = 0;
  const probe = (point) => ping(point, config);
  const logResults = (results) => { for (const item of results) console.log(`- ${item.name || item.pointId} : ${item.ipAddress || "Chưa có IP"} : ${item.status}`); };

  async function monitorOnce() {
    const runId = monitorRunId;
    // Freeze the inputs for this cycle. A concurrency change replaces the
    // shared configuration while a cycle may still be awaiting ping results;
    // reading the mutable arrays below would then produce mixed totals/batches.
    const cycleConcurrency = monitorConcurrency;
    // Khi vừa bật hoặc vừa nhận cấu hình mới, phải gửi kết quả của toàn bộ
    // vòng đầu tiên, kể cả khi trạng thái trùng với cache cũ. Nếu lọc thay đổi
    // theo từng batch, các endpoint ở cuối vòng có thể mãi giữ unknown trên UI.
    const sendAllResults = monitorInitialCyclePending;
    const cyclePoints = orderCyclePoints(monitorPoints, lastObservedStatuses, monitorRotation);
    monitorRotation = (monitorRotation + cycleConcurrency) % Math.max(1, cyclePoints.length);
    let total = 0;
    for (let offset = 0; offset < cyclePoints.length; offset += cycleConcurrency) {
      if (runId !== monitorRunId) return;
      const results = await Promise.all(cyclePoints.slice(offset, offset + cycleConcurrency).map(probe));
      for (const item of results) lastObservedStatuses.set(item.pointId, item.status);
      const changedResults = resultsToSend(results, lastSentStatuses, sendAllResults);
      const batch = { start: offset + 1, end: offset + results.length, total: cyclePoints.length, concurrency: cycleConcurrency, sentAt: new Date().toISOString(), allResults: results };
      if (!changedResults.length) {
        console.log(`[${batch.sentAt}] monitoring batch ${offset + 1}-${offset + results.length}/${cyclePoints.length} with ${cycleConcurrency} concurrent pings: no status changes`);
        logResults(results);
        continue;
      }
      const response = await client.postJson(client.telemetryUrl, { agentId: config.agentId, timestamp: batch.sentAt, results: changedResults, monitorBatch: batch });
      if (!response.ok) throw new Error(`Relay monitor upload returned ${response.status}`);
      total += results.length;
      for (const item of changedResults) lastSentStatuses.set(item.pointId, item.status);
      console.log(`[${batch.sentAt}] monitoring batch ${offset + 1}-${offset + results.length}/${cyclePoints.length} with ${cycleConcurrency} concurrent pings`);
      logResults(results);
    }
    monitorInitialCyclePending = false;
    return total;
  }

  async function monitorLoop() {
    const runId = ++monitorRunId;
    while (runId === monitorRunId && monitorPoints.length > 0) {
      await monitorOnce();
      if (runId !== monitorRunId) return;
      await new Promise((resolve) => { monitorTimer = setTimeout(resolve, monitorWaitSeconds * 1000); });
    }
  }

  function start(command) {
    const previousConcurrency = monitorConcurrency;
    const previousWaitSeconds = monitorWaitSeconds;
    monitorRunId += 1;
    monitoringActive = true;
    monitorPoints = (command.points || []).map((point) => ({ ...point, name: point.name || point.pointId }));
    lastSentStatuses.clear();
    lastObservedStatuses.clear();
    monitorInitialCyclePending = true;
    monitorRotation = 0;
    monitorConcurrency = command.concurrency || 1;
    monitorWaitSeconds = command.waitSeconds || 3;
    clearTimeout(monitorTimer);
    console.log(`continuous monitoring started/updated: reset status cache${command.resetStatuses ? " and restarting from unknown" : ""}; ${monitorConcurrency} concurrent pings, ${monitorWaitSeconds}s wait after each cycle${previousConcurrency === monitorConcurrency ? "" : ` (was ${previousConcurrency} concurrent)`}${previousWaitSeconds === monitorWaitSeconds ? "" : ` (was ${previousWaitSeconds}s wait)`}; ${monitorPoints.length} points`);
    void monitorLoop().catch((error) => console.error(error.message));
  }

  function stop() {
    monitoringActive = false;
    monitorRunId += 1;
    clearTimeout(monitorTimer);
    monitorTimer = undefined;
    monitorPoints = [];
    console.log("continuous monitoring stopped");
  }

  // Đổi IP một điểm ngay trong vòng đang chạy, rồi ping thử và gửi kết quả ngay.
  async function configurePoint(command) {
    const existing = monitorPoints.find((point) => point.pointId === command.pointId);
    monitorPoints = existing
      ? monitorPoints.map((point) => point.pointId === command.pointId ? { ...point, ipAddress: command.ipAddress } : point)
      : [...monitorPoints, { pointId: command.pointId, ipAddress: command.ipAddress }];
    lastSentStatuses.delete(command.pointId);
    console.log(`${existing ? "updated" : "added"} ${command.pointId} IP to ${command.ipAddress}; ${monitorPoints.length} monitoring points`);
    if (command.forceTest !== false) {
      const result = await probe({ pointId: command.pointId, ipAddress: command.ipAddress });
      lastObservedStatuses.set(command.pointId, result.status);
      const upload = await client.postJson(client.telemetryUrl, { agentId: config.agentId, timestamp: result.checkedAt, results: [result] });
      if (!upload.ok) throw new Error(`IP update test upload returned ${upload.status}`);
      lastSentStatuses.set(command.pointId, result.status);
      console.log(`tested updated IP ${command.pointId} ${command.ipAddress}: ${result.status}`);
    }
  }

  return { start, stop, configurePoint, isActive: () => monitoringActive };
}
