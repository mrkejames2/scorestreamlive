export function createArtworkPicker({ actions, onSelect }) {
  const root = document.createElement("div");
  root.className = "m19hf6-library";

  const label = document.createElement("div");
  label.className = "m19hf6-library-label";
  label.textContent = "Artwork Library";

  const picker = document.createElement("div");
  picker.className = "m19hf6-picker";

  const button = document.createElement("button");
  button.type = "button";
  button.className = "m19hf6-picker-button";
  button.setAttribute("aria-haspopup", "listbox");
  button.setAttribute("aria-expanded", "false");

  const menu = document.createElement("div");
  menu.className = "m19hf6-picker-menu";
  menu.setAttribute("role", "listbox");
  menu.hidden = true;

  picker.append(button, menu);
  root.append(label, picker);
  actions.prepend(root);

  let items = [];
  let selectedId = "";

  function thumb(url, alt = "") {
    if (!url) {
      const empty = document.createElement("span");
      empty.className = "m19hf6-picker-thumb-empty";
      empty.textContent = "No image";
      return empty;
    }

    const img = document.createElement("img");
    img.className = "m19hf6-picker-thumb";
    img.src = url;
    img.alt = alt;
    img.loading = "lazy";
    return img;
  }

  function renderButton() {
    button.replaceChildren();

    const selected = items.find(item => item.id === selectedId);

    if (selected) {
      button.append(thumb(selected.image_url, ""));
      const copy = document.createElement("span");
      copy.className = "m19hf6-picker-copy";

      const name = document.createElement("span");
      name.className = "m19hf6-picker-name";
      name.textContent = selected.name;

      const hint = document.createElement("span");
      hint.className = "m19hf6-picker-hint";
      hint.textContent = "Selected artwork";

      copy.append(name, hint);
      button.append(copy);
    } else {
      button.append(thumb("", ""));

      const copy = document.createElement("span");
      copy.className = "m19hf6-picker-copy";

      const name = document.createElement("span");
      name.className = "m19hf6-picker-name";
      name.textContent = "Select artwork";

      const hint = document.createElement("span");
      hint.className = "m19hf6-picker-hint";
      hint.textContent = "Choose from the reusable library";

      copy.append(name, hint);
      button.append(copy);
    }

    const chevron = document.createElement("span");
    chevron.className = "m19hf6-picker-chevron";
    chevron.textContent = menu.hidden ? "▾" : "▴";
    button.append(chevron);
  }

  function renderMenu() {
    menu.replaceChildren();

    if (!items.length) {
      const empty = document.createElement("div");
      empty.className = "m19hf6-library-empty";
      empty.textContent = "No reusable artwork has been uploaded yet.";
      menu.append(empty);
      return;
    }

    items.forEach(item => {
      const row = document.createElement("button");
      row.type = "button";
      row.className = "m19hf6-picker-item";
      row.setAttribute("role", "option");
      row.setAttribute(
        "aria-selected",
        item.id === selectedId ? "true" : "false"
      );

      if (item.id === selectedId) {
        row.classList.add("is-selected");
      }

      row.append(thumb(item.image_url, ""));

      const name = document.createElement("span");
      name.className = "m19hf6-picker-item-name";
      name.textContent = item.name;

      const mark = document.createElement("span");
      mark.className = "m19hf6-selected-mark";
      mark.textContent = item.id === selectedId ? "✓" : "";

      row.append(name, mark);

      row.addEventListener("click", async () => {
        menu.hidden = true;
        button.setAttribute("aria-expanded", "false");
        renderButton();

        if (item.id === selectedId) return;
        await onSelect(item.id);
      });

      menu.append(row);
    });
  }

  function setOpen(open) {
    menu.hidden = !open;
    button.setAttribute("aria-expanded", open ? "true" : "false");
    renderButton();
  }

  button.addEventListener("pointerdown", event => {
    event.preventDefault();
    event.stopPropagation();
    setOpen(menu.hidden);
  });

  picker.addEventListener("pointerdown", event => {
    event.stopPropagation();
  });

  document.addEventListener("pointerdown", event => {
    if (!root.contains(event.target) && !menu.hidden) {
      setOpen(false);
    }
  });

  renderButton();

  return {
    setItems(newItems) {
      items = Array.isArray(newItems) ? newItems : [];
      renderButton();
      renderMenu();
    },

    setSelected(id) {
      selectedId = id || "";
      renderButton();
      renderMenu();
    }
  };
}
