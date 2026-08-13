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

  const run = async () => {
    publish({status: "waiting"});
    await waitUntil(() => window.aiopsMermaidReady, "Mermaid startup");
    await window.aiopsMermaidReady;

    const panels = Array.from(document.querySelectorAll(".map-panel"));
    const initiallyOpen = new Set(panels.filter(panel => panel.open));
    for (const panel of panels) {
      phase = `render:${panel.dataset.map || "unknown"}`;
      panel.open = true;
      await waitUntil(() => panel.querySelector(".mermaid svg"), `${panel.dataset.map} SVG`);
    }
    for (const panel of panels) panel.open = initiallyOpen.has(panel);

    const graphs = Array.from(document.querySelectorAll(".mermaid"));
    const rendered = graphs.filter(graph => graph.querySelector("svg"));
    const root = document.documentElement;
    const tableViewport = document.querySelector(".table-scroll");
    const mapPanel = panels.find(panel => initiallyOpen.has(panel)) || panels[0];
    const mapViewport = mapPanel && mapPanel.querySelector(".map-viewport");
    const graph = mapPanel && mapPanel.querySelector(".mermaid");
    const zoomIn = mapPanel && mapPanel.querySelector('[data-zoom="in"]');
    const summary = mapPanel && mapPanel.querySelector(".map-summary");

    const zoomBefore = graph ? graph.dataset.zoomLevel : null;
    phase = "zoom";
    if (zoomIn) zoomIn.click();
    const zoomAfter = graph ? graph.dataset.zoomLevel : null;
    const transformAfter = graph ? graph.style.transform : null;

    const openBefore = Boolean(mapPanel && mapPanel.open);
    phase = "collapse";
    if (summary) summary.click();
    const collapsed = Boolean(mapPanel && !mapPanel.open);
    if (summary) summary.click();
    const expanded = Boolean(mapPanel && mapPanel.open);
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
