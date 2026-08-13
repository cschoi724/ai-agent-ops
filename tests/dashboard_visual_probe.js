(() => {
  const errors = [];
  let phase = "render";
  const recordError = value => {
    const message = value && value.stack ? value.stack : value && value.message ? value.message : String(value || "unknown browser error");
    errors.push(`${phase}: ${message}`);
  };
  window.addEventListener("error", event => recordError(event.error || event.message));
  window.addEventListener("unhandledrejection", event => recordError(event.reason));

  const publish = result => {
    document.documentElement.dataset.aiopsVisualResult = window.btoa(JSON.stringify(result));
  };
  const delay = milliseconds => new Promise(resolve => window.setTimeout(resolve, milliseconds));
  const waitUntil = async (predicate, label) => {
    for (let attempt = 0; attempt < 300; attempt += 1) {
      if (predicate()) return;
      await delay(100);
    }
    throw new Error(`timed out waiting for ${label}`);
  };

  const sortedTaskIds = values => [...new Set(values)].sort();
  const visibleTableTaskIds = () => sortedTaskIds(
    Array.from(document.querySelectorAll(".task-row"))
      .filter(row => !row.hidden)
      .map(row => row.dataset.taskId)
  );
  const dependencyTaskIds = graph => sortedTaskIds(
    (graph?.querySelector("svg")?.textContent || "").match(/T-\d{8}-\d{3}/g) || []
  );
  const sameTaskIds = (left, right) => JSON.stringify(left) === JSON.stringify(right);

  const run = async () => {
    publish({status: "waiting"});
    await waitUntil(() => window.aiopsMermaidReady, "Mermaid startup");
    await window.aiopsMermaidReady;

    const panels = Array.from(document.querySelectorAll(".map-panel"));
    const initiallyOpen = new Set(panels.filter(panel => panel.open));
    await waitUntil(
      () => Array.from(initiallyOpen).every(panel => panel.querySelector(".mermaid svg")),
      "initially open Mermaid SVGs"
    );
    const initialOpenMaps = Array.from(initiallyOpen).map(panel => panel.dataset.map || "unknown");
    const initialSvgMaps = panels.filter(panel => panel.querySelector(".mermaid svg")).map(panel => panel.dataset.map || "unknown");
    const closedInitiallyRendered = panels
      .filter(panel => !initiallyOpen.has(panel) && panel.querySelector(".mermaid svg"))
      .map(panel => panel.dataset.map || "unknown");

    const graph = document.getElementById("dependency-graph");
    const explorerData = JSON.parse(document.getElementById("dashboard-explorer-data")?.textContent || "{}");
    const explorer = {
      search: document.getElementById("explorer-search"),
      agent: document.getElementById("explorer-agent"),
      role: document.getElementById("explorer-role"),
      workflow: document.getElementById("explorer-workflow"),
      focus: document.getElementById("explorer-focus"),
      depth: document.getElementById("explorer-depth"),
      reset: document.getElementById("explorer-reset")
    };
    const interactionResults = {};
    const recordExplorer = async (name, expectedTaskIds) => {
      const expected = sortedTaskIds(expectedTaskIds);
      await waitUntil(() => {
        const tableIds = visibleTableTaskIds();
        const graphIds = dependencyTaskIds(graph);
        return sameTaskIds(tableIds, expected) && sameTaskIds(graphIds, expected);
      }, `${name} table and dependency map synchronization`);
      interactionResults[name] = {
        expected_task_ids: expected,
        table_task_ids: visibleTableTaskIds(),
        dependency_task_ids: dependencyTaskIds(graph)
      };
    };
    const resetExplorer = async () => {
      explorer.reset.click();
      await recordExplorer("reset", ["T-20260813-002", "T-20260813-003", "T-20260813-004"]);
    };
    const change = control => control.dispatchEvent(new Event(control === explorer.search ? "input" : "change", {bubbles: true}));

    phase = "explorer:initial";
    await recordExplorer("initial", ["T-20260813-002", "T-20260813-003", "T-20260813-004"]);

    phase = "explorer:search";
    explorer.search.value = "T-20260813-003";
    change(explorer.search);
    await recordExplorer("search", ["T-20260813-003"]);
    await resetExplorer();

    phase = "explorer:status";
    document.querySelectorAll("input[name=explorer-status]").forEach(input => {
      input.checked = input.value === "approved";
    });
    change(document.querySelector('input[name=explorer-status][value="approved"]'));
    await recordExplorer("status", ["T-20260813-002"]);
    await resetExplorer();

    phase = "explorer:agent";
    const agentOption = Array.from(explorer.agent.options).find(option => option.textContent.trim() === "iOS Agent");
    if (!agentOption) throw new Error("iOS Agent explorer option missing");
    explorer.agent.value = agentOption.value;
    change(explorer.agent);
    await recordExplorer("agent", ["T-20260813-002"]);
    await resetExplorer();

    const verificationTask = explorerData.tasks.find(task => task.id === "T-20260813-003");
    if (!verificationTask) throw new Error("verification fixture task missing from Explorer data");
    phase = "explorer:role";
    explorer.role.value = verificationTask.role;
    change(explorer.role);
    await recordExplorer("role", ["T-20260813-003"]);
    await resetExplorer();

    phase = "explorer:workflow";
    explorer.workflow.value = verificationTask.workflow;
    change(explorer.workflow);
    await recordExplorer("workflow", ["T-20260813-003"]);
    await resetExplorer();

    phase = "explorer:focus-depth";
    explorer.focus.value = "T-20260813-002";
    explorer.depth.value = "1";
    change(explorer.focus);
    await recordExplorer("focus_depth", ["T-20260813-002", "T-20260813-003"]);
    await resetExplorer();

    for (const panel of panels) {
      phase = `render:${panel.dataset.map || "unknown"}`;
      panel.open = true;
      await waitUntil(() => panel.querySelector(".mermaid svg"), `${panel.dataset.map} SVG`);
    }
    const closedRenderedAfterExpand = panels
      .filter(panel => !initiallyOpen.has(panel) && panel.querySelector(".mermaid svg"))
      .map(panel => panel.dataset.map || "unknown");

    const graphs = Array.from(document.querySelectorAll(".mermaid"));
    const rendered = graphs.filter(graph => graph.querySelector("svg"));
    const root = document.documentElement;
    const tableViewport = document.querySelector(".table-scroll");
    const mapPanel = panels.find(panel => initiallyOpen.has(panel)) || panels[0];
    const mapViewport = mapPanel && mapPanel.querySelector(".map-viewport");
    const zoomGraph = mapPanel && mapPanel.querySelector(".mermaid");
    const zoomIn = mapPanel && mapPanel.querySelector('[data-zoom="in"]');
    const summary = mapPanel && mapPanel.querySelector(".map-summary");

    const zoomBefore = zoomGraph ? zoomGraph.dataset.zoomLevel : null;
    phase = "zoom";
    if (zoomIn) zoomIn.click();
    const zoomAfter = zoomGraph ? zoomGraph.dataset.zoomLevel : null;
    const transformAfter = zoomGraph ? zoomGraph.style.transform : null;

    const openBefore = Boolean(mapPanel && mapPanel.open);
    phase = "collapse";
    if (summary) summary.click();
    const collapsed = Boolean(mapPanel && !mapPanel.open);
    if (summary) summary.click();
    const expanded = Boolean(mapPanel && mapPanel.open);
    for (const panel of panels) panel.open = true;
    phase = "measure";

    const outsideScrollableRegion = element => !element.closest(".map-viewport,.table-scroll,pre");
    const escapedElements = Array.from(document.querySelectorAll("button,input,select,h1,h2,.badge,.field span"))
      .filter(outsideScrollableRegion)
      .filter(element => {
        const rect = element.getBoundingClientRect();
        return rect.width > 0 && (rect.left < -1 || rect.right > root.clientWidth + 1);
      })
      .map(element => element.tagName + (element.className ? `.${String(element.className).trim().replace(/\s+/g, ".")}` : ""));

    const clippedControls = Array.from(document.querySelectorAll("button,input,select,h1,h2,.badge,.field span"))
      .filter(outsideScrollableRegion)
      .filter(element => element.clientWidth > 0 && element.scrollWidth > element.clientWidth + 1)
      .map(element => element.tagName + (element.className ? `.${String(element.className).trim().replace(/\s+/g, ".")}` : ""));

    publish({
      status: "ok",
      lang: root.lang,
      graph_count: graphs.length,
      svg_count: rendered.length,
      initial_open_count: initialOpenMaps.length,
      initial_open_maps: initialOpenMaps,
      initial_svg_count: initialSvgMaps.length,
      initial_svg_maps: initialSvgMaps,
      closed_initially_rendered: closedInitiallyRendered,
      closed_rendered_after_expand: closedRenderedAfterExpand,
      explorer_interactions: interactionResults,
      artifact_all_maps_open: panels.every(panel => panel.open),
      page_client_width: root.clientWidth,
      page_scroll_width: root.scrollWidth,
      table_client_width: tableViewport ? tableViewport.clientWidth : 0,
      table_scroll_width: tableViewport ? tableViewport.scrollWidth : 0,
      map_client_width: mapViewport ? mapViewport.clientWidth : 0,
      map_scroll_width: mapViewport ? mapViewport.scrollWidth : 0,
      zoom_before: zoomBefore,
      zoom_after: zoomAfter,
      transform_after: transformAfter,
      open_before: openBefore,
      collapsed,
      expanded,
      escaped_elements: escapedElements,
      clipped_controls: clippedControls,
      errors
    });
  };

  run().catch(error => publish({status: "error", phase, message: error.stack || error.message, errors}));
})();
