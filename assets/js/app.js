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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import Plotly.js
import Plotly from 'plotly.js-dist'

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Add this to your Hooks object
let Hooks = {}

Hooks.PlotlyChart = {
  mounted() {

    // Send the chart ID when requesting data
    this.handleEvent(`plotly-data-${this.el.id}`, ({ data, layout, config }) => {
      // Only update if this event is for this chart or if no ID is specified

      Plotly.newPlot(this.el, data, layout || {}, config || {});

    });
    
    this.handleEvent("plotly-update", ({  data, layout, config }) => {
      // Only update if this event is for this chart or if no ID is specified
      

      Plotly.react(this.el, data, layout || {});

      // Explicitly null out references to help garbage collection
      data = null;
      layout = null;
      config = null;


    });

    // Add new handler for extending traces (real-time updates)
    this.handleEvent(`extend-traces-${this.el.id}`, ({ x, y, traceIndices }) => {
      try {
        // Ensure we have an initialized plot before trying to extend it
        if (this.el._fullData) {
          // Use extendTraces to efficiently add new points
          Plotly.extendTraces(this.el, {
            x: x,  // Array of x arrays
            y: y   // Array of y arrays
          }, traceIndices || [0]);
        } else {
          // If plot isn't initialized, request full data
          this.pushEventTo(this.el, "request-plotly-data", { id: this.el.id });
        }
      } catch (error) {
        console.error("Error extending traces:", error);
      }
    });

    
    this.handleEvent("plotly-add-traces", ({  traces, newIndices }) => {
      // Only update if this event is for this chart or if no ID is specified

        Plotly.addTraces(this.el, traces, newIndices || null);

    });
    
    // Request initial data when the hook is mounted, include the chart ID
    this.pushEventTo(this.el,"request-plotly-data", { id: this.el.id });
  },
  
  destroyed() {
    Plotly.purge(this.el);
  }
}

// Register hooks with LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

function darkExpected() {
  return localStorage.theme === 'dark' || (!('theme' in localStorage) &&
    window.matchMedia('(prefers-color-scheme: dark)').matches);
}

function initDarkMode() {
  // On page load or when changing themes, best to add inline in `head` to avoid FOUC
  if (darkExpected()) {
    document.documentElement.classList.add('dark');
    document.getElementById('theme-toggle-dark-icon').classList.add('hidden');
    document.getElementById('theme-toggle-light-icon').classList.remove('hidden');
  } else {
    document.documentElement.classList.remove('dark');
    document.getElementById('theme-toggle-dark-icon').classList.remove('hidden');
    document.getElementById('theme-toggle-light-icon').classList.add('hidden');
  }
}
window.addEventListener("toogle-darkmode", e => {
  if (darkExpected()) localStorage.theme = 'light';
  else localStorage.theme = 'dark';
  initDarkMode();
})

initDarkMode();