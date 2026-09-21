export async function initBroadcastPresentation(gameId) {
  const root = document.getElementById("m19h-broadcast-controls");
  if (!root) return;

  let state = null;

  const label = document.getElementById("m19h-scene-state");
  const message = document.getElementById("m19h-broadcast-message");

  const intro = document.getElementById("m19h-show-intro");
  const live = document.getElementById("m19h-go-live");
  const summary = document.getElementById("m19hf1b-show-summary");
  const thankYou = document.getElementById("m19hf1b-show-thank-you");

  const copyStreamUrl = document.getElementById("m19hf1b-copy-stream-url");
  const streamUrl = document.getElementById("m19hf1b-stream-url");

  function draw() {
    const scene = state?.scene || "live";

    label.textContent = scene.toUpperCase().replace("_", " ");

    intro.disabled = !state?.intro?.image_url;
    thankYou.disabled = !state?.thank_you?.image_url;

    for (const [name, button] of [
      ["intro", intro],
      ["live", live],
      ["summary", summary],
      ["thank_you", thankYou],
    ]) {
      button.setAttribute("aria-pressed", String(name === scene));
    }
  }

  async function recover() {
    const response = await fetch(
      `/api/games/${gameId}/broadcast-presentation`,
      { cache: "no-store" }
    );

    if (response.ok) {
      state = await response.json();
      draw();
    }
  }

  async function setScene(scene) {
    const response = await fetch(
      `/api/games/${gameId}/broadcast-presentation`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          scene,
          expected_version: state?.version ?? 0,
        }),
      }
    );

    if (response.ok) {
      state = await response.json();
      draw();

      message.textContent = {
        intro: "Welcome Screen is live.",
        live: "Live Game scene is active.",
        summary: "Game Summary is live.",
        thank_you: "Thank You Screen is live.",
      }[scene];

      return;
    }

    const body = await response.json().catch(() => ({}));
    message.textContent = body.detail || "Scene change failed";

    await recover();
  }

  async function copyCanonicalStreamUrl() {
    if (!copyStreamUrl || !streamUrl) return;

    const absoluteUrl = new URL(
      streamUrl.textContent.trim(),
      window.location.origin
    ).href;

    const originalText = copyStreamUrl.textContent;

    try {
      await navigator.clipboard.writeText(absoluteUrl);
      copyStreamUrl.textContent = "Copied!";
    } catch (error) {
      console.error("Copy Stream URL failed", error);

      const textarea = document.createElement("textarea");
      textarea.value = absoluteUrl;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";

      document.body.appendChild(textarea);
      textarea.select();

      const copied = document.execCommand("copy");
      textarea.remove();

      copyStreamUrl.textContent = copied ? "Copied!" : "Copy Failed";
    }

    window.setTimeout(() => {
      copyStreamUrl.textContent = originalText;
    }, 1500);
  }

  intro.onclick = () => setScene("intro");
  live.onclick = () => setScene("live");
  summary.onclick = () => setScene("summary");
  thankYou.onclick = () => setScene("thank_you");

  if (copyStreamUrl) {
    copyStreamUrl.addEventListener("click", copyCanonicalStreamUrl);
  }

  await recover();
}
