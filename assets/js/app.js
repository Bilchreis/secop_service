// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/secop_service";
import topbar from "../vendor/topbar";

// Import Plotly.js
import Plotly from "plotly.js-dist-min";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const maxPoints = 20000; // Default max points for extendTraces

// Add this to your Hooks object
let Hooks = {};

Hooks.PlotlyChart = {
  mounted() {
    // Buffer for incoming trace data: { traceIndex -> { x: [], y: [] } }
    this._traceBuffer = {};

    // Flush buffered trace data to Plotly at a fixed render rate (2s),
    // decoupled from however often the server sends push_events.
    this._flushInterval = setInterval(() => this._flushTraceBuffer(), 3000);

    // Send the chart ID when requesting data
    this.handleEvent(
      `plotly-data-${this.el.id}`,
      ({ data, layout, config }) => {
        // Only update if this event is for this chart or if no ID is specified

        // Get the loading element ID from data attribute
        const loadingId = this.el.dataset.loadingId;
        const loadingElement = document.getElementById(loadingId);

        // After Plotly is initialized and chart is rendered
        Plotly.newPlot(this.el, data, layout, config).then(() => {
          // Hide the loading overlay when Plotly is ready
          if (loadingElement) {
            loadingElement.style.display = "none";
          }
        });
      },
    );

    this.handleEvent("plotly-update", ({ data, layout, config }) => {
      // Only update if this event is for this chart or if no ID is specified

      Plotly.react(this.el, data, layout || {});

      // Explicitly null out references to help garbage collection
      data = null;
      layout = null;
      config = null;
    });

    // Buffer incoming trace updates instead of calling Plotly immediately.
    // The _flushTraceBuffer timer will drain the buffer and call extendTraces once.
    this.handleEvent(
      `extend-traces-${this.el.id}`,
      ({ x, y, traceIndices }) => {
        const indices = traceIndices || [0];
        indices.forEach((traceIdx, i) => {
          if (!this._traceBuffer[traceIdx]) {
            this._traceBuffer[traceIdx] = { x: [], y: [] };
          }
          this._traceBuffer[traceIdx].x.push(...x[i]);
          this._traceBuffer[traceIdx].y.push(...y[i]);
        });
      },
    );

    this._toggleRangeslider = (e) => {
      if (e.target.dataset.chartId === this.el.id) {
        const currentVisible =
          this.el.layout?.xaxis?.rangeslider?.visible ?? false;
        Plotly.relayout(this.el, {
          "xaxis.rangeslider.visible": !currentVisible,
        });
      }
    };
    document.addEventListener("toggle-rangeslider", this._toggleRangeslider);

    // Handle cleanup event
    this.handleEvent(`cleanup-plots`, () => {
      this.destroyed();
    });

    // Purge plot when a parent modal closes
    this._onCloseModal = () => {
      if (this.el.closest("dialog")) {
        Plotly.purge(this.el);
      }
    };
    window.addEventListener("myapp:close-modal", this._onCloseModal);

    // Request initial data when the hook is mounted, include the chart ID
    this.pushEventTo(this.el, "request-plotly-data", { id: this.el.id });
  },

  _flushTraceBuffer() {
    if (!this.el._fullData) return;

    const indices = Object.keys(this._traceBuffer).map(Number);
    if (indices.length === 0) return;

    // Drain the buffer atomically so concurrent events don't race
    const buffer = this._traceBuffer;
    this._traceBuffer = {};

    const sortedIndices = indices.sort((a, b) => a - b);
    const xData = sortedIndices.map((i) => buffer[i].x);
    const yData = sortedIndices.map((i) => buffer[i].y);

    try {
      Plotly.extendTraces(
        this.el,
        { x: xData, y: yData },
        sortedIndices,
        maxPoints,
      );

      // Update x-axis range once per flush, not once per incoming event
      const now = new Date();
      const layout = this.el.layout;
      const currentXRange = layout.xaxis.range;
      let shouldUpdateRange = false;
      let newRange = null;

      const rangeSelector = layout.xaxis.rangeselector;
      const activeButton = rangeSelector ? rangeSelector.activebutton : null;

      if (activeButton !== null && activeButton !== undefined) {
        const button = rangeSelector.buttons[activeButton];
        if (button.step !== "all") {
          let startTime;
          if (button.step === "minute") {
            startTime = new Date(now.getTime() - button.count * 60 * 1000);
          } else if (button.step === "hour") {
            startTime = new Date(
              now.getTime() - button.count * 60 * 60 * 1000,
            );
          } else if (button.step === "day") {
            startTime = new Date(
              now.getTime() - button.count * 24 * 60 * 60 * 1000,
            );
          }
          if (startTime) {
            newRange = [startTime, now];
            shouldUpdateRange = true;
          }
        }
      } else if (currentXRange && currentXRange.length === 2) {
        const rightEdge = new Date(currentXRange[1]);
        const timeDiff = Math.abs(rightEdge.getTime() - now.getTime());
        if (timeDiff < 60000) {
          const windowSize =
            rightEdge.getTime() - new Date(currentXRange[0]).getTime();
          newRange = [new Date(now.getTime() - windowSize), now];
          shouldUpdateRange = true;
        }
      } else {
        newRange = [new Date(now.getTime() - 10 * 60 * 1000), now];
        shouldUpdateRange = true;
      }

      if (shouldUpdateRange && newRange) {
        Plotly.relayout(this.el, { "xaxis.range": newRange });
      }
    } catch (error) {
      console.error("Error flushing trace buffer:", error);
    }
  },

  destroyed() {
    if (this._flushInterval) {
      clearInterval(this._flushInterval);
    }
    if (this._toggleRangeslider) {
      document.removeEventListener(
        "toggle-rangeslider",
        this._toggleRangeslider,
      );
    }
    if (this._onCloseModal) {
      window.removeEventListener("myapp:close-modal", this._onCloseModal);
    }
    if (this.el) {
      Plotly.purge(this.el);
    }
  },
};

// CopyToClipboard hook for copying text with visual feedback
Hooks.CopyToClipboard = {
  mounted() {
    this.originalTooltip = this.el.dataset.tip;

    this.el.addEventListener("click", () => {
      const textToCopy = this.el.dataset.copy;

      navigator.clipboard
        .writeText(textToCopy)
        .then(() => {
          // Change tooltip to show success
          this.el.dataset.tip = "✓ Copied!";
          this.el.classList.add("tooltip-success");

          // Revert back after 2 seconds
          setTimeout(() => {
            this.el.dataset.tip = this.originalTooltip;
            this.el.classList.remove("tooltip-success");
          }, 2000);
        })
        .catch((err) => {
          console.error("Failed to copy:", err);
          // Show error feedback
          this.el.dataset.tip = "✗ Failed to copy";
          this.el.classList.add("tooltip-error");

          setTimeout(() => {
            this.el.dataset.tip = this.originalTooltip;
            this.el.classList.remove("tooltip-error");
          }, 2000);
        });
    });
  },
};

// Register hooks with LiveSocket
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...Hooks, ...colocatedHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
