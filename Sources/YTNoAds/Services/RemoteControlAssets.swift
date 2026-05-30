import Foundation

extension RemoteControlServer {
    static let indexHTML = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <title>YT No Ads Remote</title>
      <link rel="stylesheet" href="/app.css">
    </head>
    <body>
      <main class="remote-shell">
        <section class="search-panel">
          <form id="search-form" class="search-form">
            <input id="search-input" type="search" placeholder="Search YouTube" autocomplete="off" autocorrect="off">
            <button id="search-button" type="submit">Search</button>
          </form>
          <p id="search-status" class="search-status"></p>
          <div id="search-results" class="search-results" hidden></div>
        </section>

        <section class="artwork-wrap">
          <img id="thumbnail" class="artwork" alt="" hidden>
          <div id="empty-artwork" class="empty-artwork">
            <span class="play-glyph">▶</span>
          </div>
          <div id="status-pill" class="status-pill">Disconnected</div>
        </section>

        <section class="meta">
          <p id="channel" class="channel">YT No Ads</p>
          <h1 id="title">Waiting for video</h1>
        </section>

        <section class="timeline">
          <input id="scrubber" type="range" min="0" max="1" step="0.1" value="0">
          <div class="time-row">
            <span id="current-time">0:00</span>
            <span id="duration">0:00</span>
          </div>
        </section>

        <section class="transport">
          <button data-command="seekBy" data-seconds="-10" aria-label="Back 10 seconds">↺ 10</button>
          <button id="play-pause" class="primary" data-command="togglePlayPause" aria-label="Play or pause">▶</button>
          <button data-command="seekBy" data-seconds="10" aria-label="Forward 10 seconds">10 ↻</button>
        </section>

        <section class="control-grid">
          <label class="field">
            <span>Volume</span>
            <input id="volume" type="range" min="0" max="1" step="0.01" value="0.8">
          </label>

          <label class="field">
            <span>Quality</span>
            <select id="quality"></select>
          </label>
        </section>

        <section class="actions">
          <button data-command="toggleFullscreen">Fullscreen</button>
          <button data-command="closePlayer">Close</button>
        </section>
      </main>

      <script src="/app.js"></script>
    </body>
    </html>
    """

    static let css = """
    :root {
      color-scheme: dark;
      --bg: #121215;
      --panel: #1d1c22;
      --panel-strong: #2a2930;
      --text: #f5f3f7;
      --muted: #aaa5b4;
      --accent: #3b82f6;
      --good: #22c55e;
      --warn: #f59e0b;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--text);
    }

    button, input, select {
      font: inherit;
    }

    .remote-shell {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      gap: 22px;
      padding: max(18px, env(safe-area-inset-top)) 18px max(22px, env(safe-area-inset-bottom));
    }

    .artwork-wrap {
      position: relative;
      width: 100%;
      aspect-ratio: 16 / 9;
      border-radius: 8px;
      overflow: hidden;
      background: #050505;
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.32);
    }

    .artwork, .empty-artwork {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .empty-artwork {
      display: grid;
      place-items: center;
      background: linear-gradient(135deg, #20232b, #111114);
    }

    .play-glyph {
      width: 64px;
      height: 44px;
      display: grid;
      place-items: center;
      border: 2px solid rgba(255, 255, 255, 0.42);
      border-radius: 8px;
      color: rgba(255, 255, 255, 0.62);
      padding-left: 4px;
    }

    .status-pill {
      position: absolute;
      left: 12px;
      bottom: 12px;
      max-width: calc(100% - 24px);
      padding: 7px 10px;
      border-radius: 999px;
      background: rgba(0, 0, 0, 0.72);
      color: white;
      font-size: 13px;
      font-weight: 650;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .search-panel {
      display: grid;
      gap: 10px;
    }

    .search-form {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 10px;
    }

    input[type="search"] {
      min-height: 48px;
      width: 100%;
      border: 0;
      border-radius: 8px;
      background: var(--panel);
      color: var(--text);
      padding: 0 14px;
      outline: none;
    }

    input[type="search"]::placeholder {
      color: var(--muted);
    }

    input[type="search"]:focus {
      box-shadow: 0 0 0 2px var(--accent);
    }

    .search-status {
      min-height: 18px;
      margin: 0;
      color: var(--muted);
      font-size: 13px;
    }

    .search-results {
      max-height: min(44vh, 420px);
      display: grid;
      gap: 8px;
      overflow: auto;
      padding-right: 2px;
    }

    .result-row {
      width: 100%;
      min-height: 72px;
      display: grid;
      grid-template-columns: 96px minmax(0, 1fr) auto;
      gap: 10px;
      align-items: center;
      text-align: left;
      padding: 8px;
      background: var(--panel);
    }

    .result-row[aria-current="true"] {
      box-shadow: inset 0 0 0 2px var(--accent);
    }

    .result-thumb {
      width: 96px;
      aspect-ratio: 16 / 9;
      border-radius: 6px;
      object-fit: cover;
      background: #050505;
    }

    .result-copy {
      min-width: 0;
      display: grid;
      gap: 4px;
    }

    .result-title {
      color: var(--text);
      font-size: 14px;
      font-weight: 700;
      line-height: 1.2;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .result-meta {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .result-action {
      align-self: center;
      padding: 7px 9px;
      border-radius: 999px;
      background: rgba(59, 130, 246, 0.16);
      color: #9cc2ff;
      font-size: 12px;
      font-weight: 750;
      white-space: nowrap;
    }

    .meta {
      min-height: 78px;
    }

    .channel {
      margin: 0 0 6px;
      color: var(--muted);
      font-size: 15px;
    }

    h1 {
      margin: 0;
      font-size: 23px;
      line-height: 1.18;
      letter-spacing: 0;
    }

    .timeline {
      display: grid;
      gap: 8px;
    }

    input[type="range"] {
      width: 100%;
      accent-color: var(--accent);
    }

    .time-row {
      display: flex;
      justify-content: space-between;
      color: var(--muted);
      font-size: 13px;
      font-variant-numeric: tabular-nums;
    }

    .transport {
      display: grid;
      grid-template-columns: 1fr 88px 1fr;
      gap: 12px;
      align-items: center;
    }

    button, select {
      min-height: 48px;
      border: 0;
      border-radius: 8px;
      background: var(--panel-strong);
      color: var(--text);
      font-weight: 650;
    }

    button:active {
      transform: translateY(1px);
      filter: brightness(1.12);
    }

    .primary {
      min-height: 64px;
      border-radius: 50%;
      background: var(--text);
      color: #111;
      font-size: 25px;
      padding-left: 10px;
    }

    .control-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 12px;
    }

    .field {
      display: grid;
      gap: 8px;
      padding: 14px;
      border-radius: 8px;
      background: var(--panel);
    }

    .field span {
      color: var(--muted);
      font-size: 13px;
      font-weight: 650;
    }

    select {
      width: 100%;
      padding: 0 12px;
    }

    .actions {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-top: auto;
    }

    @media (min-width: 700px) {
      .remote-shell {
        width: min(520px, 100vw);
        margin: 0 auto;
      }
    }
    """

    static let javascript = """
    const token = new URLSearchParams(location.search).get("t") || "";
    let state = null;
    let dragging = false;
    let searchResults = new Map();

    const els = {
      searchForm: document.getElementById("search-form"),
      searchInput: document.getElementById("search-input"),
      searchButton: document.getElementById("search-button"),
      searchStatus: document.getElementById("search-status"),
      searchResults: document.getElementById("search-results"),
      thumbnail: document.getElementById("thumbnail"),
      emptyArtwork: document.getElementById("empty-artwork"),
      status: document.getElementById("status-pill"),
      channel: document.getElementById("channel"),
      title: document.getElementById("title"),
      scrubber: document.getElementById("scrubber"),
      currentTime: document.getElementById("current-time"),
      duration: document.getElementById("duration"),
      playPause: document.getElementById("play-pause"),
      volume: document.getElementById("volume"),
      quality: document.getElementById("quality")
    };

    function tokenQuery() {
      return `t=${encodeURIComponent(token)}`;
    }

    function formatTime(seconds) {
      seconds = Number.isFinite(seconds) ? Math.max(0, seconds) : 0;
      const whole = Math.floor(seconds);
      const h = Math.floor(whole / 3600);
      const m = Math.floor((whole % 3600) / 60);
      const s = whole % 60;
      if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
      return `${m}:${String(s).padStart(2, "0")}`;
    }

    function statusText(nextState) {
      if (!nextState.hasVideo) return "No video selected";
      if (nextState.isBuffering) return "Buffering";
      if (nextState.sourceKind?.kind === "preview") {
        return nextState.selectedQuality === "best" ? "Preview quality - upgrading" : "Streaming preview";
      }
      if (nextState.sourceKind?.kind === "final") return "Best ready";
      return nextState.isPlaying ? "Playing" : "Paused";
    }

    function render(nextState) {
      state = nextState;
      els.status.textContent = statusText(nextState);
      els.channel.textContent = nextState.channel || "YT No Ads";
      els.title.textContent = nextState.title || "Waiting for video";
      els.playPause.textContent = nextState.isPlaying ? "Ⅱ" : "▶";
      els.volume.value = String(nextState.volume ?? 0.8);

      const duration = nextState.duration || 0;
      const current = nextState.currentTime || 0;
      els.scrubber.max = String(Math.max(duration, 1));
      if (!dragging) els.scrubber.value = String(current);
      els.currentTime.textContent = formatTime(current);
      els.duration.textContent = formatTime(duration);

      if (nextState.thumbnailURL) {
        els.thumbnail.src = nextState.thumbnailURL;
        els.thumbnail.hidden = false;
        els.emptyArtwork.hidden = true;
      } else {
        els.thumbnail.hidden = true;
        els.emptyArtwork.hidden = false;
      }

      const oldQuality = els.quality.value;
      els.quality.innerHTML = "";
      for (const option of nextState.availableQualities || []) {
        const node = document.createElement("option");
        node.value = option.id;
        node.textContent = option.title;
        els.quality.appendChild(node);
      }
      els.quality.value = nextState.selectedQuality || oldQuality || "fastStart";
    }

    async function loadState() {
      const res = await fetch(`/api/state?${tokenQuery()}`);
      if (!res.ok) throw new Error(`State failed: ${res.status}`);
      render(await res.json());
    }

    async function command(payload) {
      const res = await fetch(`/api/control?${tokenQuery()}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload)
      });
      if (!res.ok) throw new Error(`Command failed: ${res.status}`);
      const body = await res.json();
      render(body.state);
    }

    async function search(query) {
      els.searchButton.disabled = true;
      els.searchStatus.textContent = "Searching";

      try {
        const res = await fetch(`/api/search?${tokenQuery()}`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ query })
        });
        if (!res.ok) throw new Error(`Search failed: ${res.status}`);
        const body = await res.json();
        renderSearchResults(body.results || []);
      } catch (error) {
        els.searchStatus.textContent = "Search failed";
        console.error(error);
      } finally {
        els.searchButton.disabled = false;
      }
    }

    async function playResult(videoID) {
      els.searchStatus.textContent = "Starting";
      const res = await fetch(`/api/play?${tokenQuery()}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ videoID })
      });
      if (!res.ok) throw new Error(`Play failed: ${res.status}`);
      const body = await res.json();
      render(body.state);
      els.searchStatus.textContent = "Selected";
      markSelectedResult(videoID);
    }

    function renderSearchResults(results) {
      searchResults.clear();
      els.searchResults.innerHTML = "";
      els.searchResults.hidden = results.length === 0;
      els.searchStatus.textContent = results.length === 0 ? "No results" : `${results.length} results`;

      for (const result of results) {
        searchResults.set(result.id, result);
        const button = document.createElement("button");
        button.type = "button";
        button.className = "result-row";
        button.dataset.videoId = result.id;
        button.setAttribute("aria-label", `Play ${result.title}`);
        button.setAttribute("aria-current", state?.webpageURL === result.webpageURL ? "true" : "false");

        const thumbnail = document.createElement("img");
        thumbnail.className = "result-thumb";
        thumbnail.alt = "";
        if (result.thumbnailURL) thumbnail.src = result.thumbnailURL;

        const copy = document.createElement("span");
        copy.className = "result-copy";

        const title = document.createElement("span");
        title.className = "result-title";
        title.textContent = result.title || "Untitled";

        const meta = document.createElement("span");
        meta.className = "result-meta";
        const duration = result.durationSeconds ? formatTime(result.durationSeconds) : "";
        meta.textContent = [result.channelTitle, duration].filter(Boolean).join(" - ");

        copy.append(title, meta);
        const action = document.createElement("span");
        action.className = "result-action";
        action.textContent = "Select";

        button.append(thumbnail, copy, action);
        els.searchResults.append(button);
      }
    }

    function markSelectedResult(videoID) {
      els.searchResults.querySelectorAll(".result-row").forEach(row => {
        row.setAttribute("aria-current", row.dataset.videoId === videoID ? "true" : "false");
      });
    }

    function connectSocket() {
      const scheme = location.protocol === "https:" ? "wss" : "ws";
      const ws = new WebSocket(`${scheme}://${location.host}/ws?${tokenQuery()}`);
      ws.onopen = () => loadState().catch(console.error);
      ws.onmessage = event => render(JSON.parse(event.data));
      ws.onclose = () => {
        els.status.textContent = "Reconnecting";
        setTimeout(connectSocket, 1200);
      };
      ws.onerror = () => ws.close();
    }

    document.querySelectorAll("[data-command]").forEach(button => {
      button.addEventListener("click", () => {
        const name = button.dataset.command;
        const seconds = button.dataset.seconds ? Number(button.dataset.seconds) : undefined;
        command({ command: name, seconds }).catch(console.error);
      });
    });

    els.searchForm.addEventListener("submit", event => {
      event.preventDefault();
      const query = els.searchInput.value.trim();
      if (query.length > 0) search(query);
    });

    els.searchResults.addEventListener("click", event => {
      const row = event.target.closest(".result-row");
      if (!row) return;
      playResult(row.dataset.videoId).catch(error => {
        els.searchStatus.textContent = "Could not start";
        console.error(error);
      });
    });

    els.scrubber.addEventListener("pointerdown", () => dragging = true);
    els.scrubber.addEventListener("pointerup", () => {
      dragging = false;
      command({ command: "seekTo", seconds: Number(els.scrubber.value) }).catch(console.error);
    });
    els.scrubber.addEventListener("change", () => {
      command({ command: "seekTo", seconds: Number(els.scrubber.value) }).catch(console.error);
    });

    els.volume.addEventListener("input", () => {
      command({ command: "setVolume", volume: Number(els.volume.value) }).catch(console.error);
    });

    els.quality.addEventListener("change", () => {
      command({ command: "setQuality", quality: els.quality.value }).catch(console.error);
    });

    if (!token) {
      els.status.textContent = "Missing pairing code";
    } else {
      connectSocket();
      loadState().catch(console.error);
    }
    """
}
