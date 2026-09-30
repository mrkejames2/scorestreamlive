const api = async (path, options = {}) => {
  const headers = {...(options.headers || {})};

  if (
    options.body &&
    !(options.body instanceof FormData) &&
    !headers["Content-Type"]
  ) {
    headers["Content-Type"] = "application/json";
  }

  const r = await fetch(path, {
    cache: "no-store",
    ...options,
    headers
  });

  if (!r.ok) {
    let d = {};
    try {
      d = await r.json();
    } catch (_) {}

    throw new Error(d.detail || `HTTP ${r.status}`);
  }

  return r.status === 204 ? null : r.json();
};

export async function loadHalftimeSlideshow(gameId) {
  const panel = document.getElementById("m19hf7-halftime-panel");
  if (!panel) return;

  const list = document.getElementById("m19hf7-slide-list");
  const select = document.getElementById("m19hf7-artwork");
  const enabled = document.getElementById("m19hf7-enabled");
  const interval = document.getElementById("m19hf7-interval");
  const message = document.getElementById("m19hf7-message");
  const add = document.getElementById("m19hf7-add");
  const save = document.getElementById("m19hf7-save");
  const upload = document.getElementById("m19hf7-upload");
  const uploadArea = document.getElementById("m19hf7-upload-area");

  let state = {
    slides: [],
    enabled: false,
    interval_seconds: 10
  };

  let library = [];
  let canManageLibrary = false;

  const tell = text => {
    message.textContent = text || "";
  };

  async function fetchLibrary() {
    const data = await api("/api/account/broadcast-artwork");
    library = Array.isArray(data.items) ? data.items : [];
    canManageLibrary = !!data.can_manage;

    // HF6 permission contract:
    // Director may upload/manage reusable artwork.
    // Manager may select existing reusable artwork.
    if (uploadArea) {
      uploadArea.hidden = !canManageLibrary;
    }
  }

  async function load() {
    try {
      state = await api(`/api/games/${gameId}/halftime-slideshow`);
      await fetchLibrary();

      draw();
      panel.classList.remove("hidden");
    } catch (e) {
      tell(e.message);
    }
  }

  function draw() {
    enabled.checked = !!state.enabled;
    interval.value = String(state.interval_seconds || 10);

    list.replaceChildren();
    select.replaceChildren(new Option("Select artwork…", ""));

    const used = new Set(state.slides.map(x => x.artwork_id));

    for (const artwork of library) {
      if (!used.has(artwork.id)) {
        select.add(new Option(artwork.name, artwork.id));
      }
    }

    if (!state.slides.length) {
      const empty = document.createElement("p");
      empty.className = "m19hf7-empty";
      empty.textContent = "No slideshow images selected yet.";
      list.append(empty);
    }

    state.slides.forEach((slide, index) => {
      const row = document.createElement("div");
      row.className = "m19hf7-slide";

      const img = document.createElement("img");
      img.src = slide.image_url;
      img.alt = "";

      const name = document.createElement("strong");
      name.textContent = `${index + 1}. ${slide.name}`;

      const actions = document.createElement("div");

      for (const [label, delta] of [["↑", -1], ["↓", 1]]) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "button button-secondary";
        button.textContent = label;
        button.disabled =
          index + delta < 0 ||
          index + delta >= state.slides.length;

        button.onclick = () => move(index, index + delta);
        actions.append(button);
      }

      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "button button-secondary";
      removeButton.textContent = "Remove";
      removeButton.onclick = () => remove(slide.id);

      actions.append(removeButton);
      row.append(img, name, actions);
      list.append(row);
    });
  }

  async function move(from, to) {
    const ids = state.slides.map(x => x.id);
    [ids[from], ids[to]] = [ids[to], ids[from]];

    try {
      state = await api(
        `/api/games/${gameId}/halftime-slideshow/slides/order`,
        {
          method: "PUT",
          body: JSON.stringify({slide_ids: ids})
        }
      );

      draw();
      tell("Slide order saved.");
    } catch (e) {
      tell(e.message);
    }
  }

  async function remove(id) {
    try {
      await api(
        `/api/games/${gameId}/halftime-slideshow/slides/${id}`,
        {method: "DELETE"}
      );

      state = await api(
        `/api/games/${gameId}/halftime-slideshow`
      );

      await fetchLibrary();
      draw();

      tell(
        "Slide removed from this slideshow. " +
        "The reusable artwork remains in the library."
      );
    } catch (e) {
      tell(e.message);
    }
  }

  async function addArtworkToSlideshow(artworkId) {
    state = await api(
      `/api/games/${gameId}/halftime-slideshow/slides`,
      {
        method: "POST",
        body: JSON.stringify({artwork_id: artworkId})
      }
    );
  }

  add.onclick = async () => {
    if (!select.value) return;

    try {
      await addArtworkToSlideshow(select.value);
      await fetchLibrary();
      draw();
      tell("Existing artwork added to slideshow.");
    } catch (e) {
      tell(e.message);
    }
  };

  upload.onchange = async event => {
    const files = Array.from(event.target.files || []);
    if (!files.length) return;

    upload.disabled = true;
    add.disabled = true;
    save.disabled = true;

    let uploaded = 0;
    const failures = [];

    try {
      for (let i = 0; i < files.length; i++) {
        const file = files[i];

        // Use filename without extension as the reusable artwork name.
        const name =
          file.name.replace(/\.[^.]+$/, "").trim() ||
          `Halftime Slide ${i + 1}`;

        tell(
          `Uploading ${i + 1} of ${files.length}: ${file.name}`
        );

        try {
          const form = new FormData();
          form.append("name", name);
          form.append("artwork", file);

          const artwork = await api(
            "/api/account/broadcast-artwork",
            {
              method: "POST",
              body: form
            }
          );

          await addArtworkToSlideshow(artwork.id);
          uploaded += 1;
        } catch (e) {
          failures.push(`${file.name}: ${e.message}`);
        }
      }

      state = await api(
        `/api/games/${gameId}/halftime-slideshow`
      );

      await fetchLibrary();
      draw();

      if (!failures.length) {
        tell(
          `${uploaded} image${uploaded === 1 ? "" : "s"} ` +
          "uploaded and added to the slideshow."
        );
      } else {
        tell(
          `${uploaded} uploaded. ${failures.length} failed: ` +
          failures.join(" | ")
        );
      }
    } finally {
      event.target.value = "";
      upload.disabled = false;
      add.disabled = false;
      save.disabled = false;
    }
  };

  save.onclick = async () => {
    try {
      state = await api(
        `/api/games/${gameId}/halftime-slideshow`,
        {
          method: "PUT",
          body: JSON.stringify({
            enabled: enabled.checked,
            interval_seconds: Number(interval.value)
          })
        }
      );

      draw();
      tell("Halftime Slideshow saved.");
    } catch (e) {
      tell(e.message);
    }
  };

  await load();
}
