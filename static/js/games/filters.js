import { GameLibraryClassification } from "./classification.js";

const byId = (id) => document.getElementById(id);

const controls = {
  search: byId("game-library-search"),
  classification: byId("game-library-classification-filter"),
  clear: byId("game-library-clear-filters"),
  resultStatus: byId("game-library-results-status"),
  noResults: byId("game-library-no-results"),
  sections: byId("library-sections"),
};

const sectionConfig = [
  { classification: GameLibraryClassification.LIVE, section: byId("library-live"), count: byId("library-live-count") },
  { classification: GameLibraryClassification.UPCOMING, section: byId("library-upcoming"), count: byId("library-upcoming-count") },
  { classification: GameLibraryClassification.COMPLETED, section: byId("library-completed"), count: byId("library-completed-count") },
  { classification: GameLibraryClassification.CANCELLED, section: byId("library-cancelled"), count: byId("library-cancelled-count") },
];

function normalizedSearchValue(value) {
  return String(value || "").trim().toLocaleLowerCase();
}

function activeFilters() {
  return {
    query: normalizedSearchValue(controls.search?.value),
    classification: controls.classification?.value || "all",
  };
}

function cardMatchesSearch(card, query) {
  if (!query) return true;
  return normalizedSearchValue(card.dataset.searchText || card.textContent).includes(query);
}

function cardMatchesClassification(card, classification) {
  if (classification === "all") return true;
  return card.dataset.libraryClassification === classification;
}

function filteredCards(cards, filters) {
  return cards.filter(
    (card) =>
      cardMatchesSearch(card, filters.query)
      && cardMatchesClassification(card, filters.classification),
  );
}

function setSectionFilterMessage(section, visible) {
  let message = section.querySelector(".library-section-filter-message");

  if (visible) {
    if (!message) {
      message = document.createElement("p");
      message.className = "library-section-filter-message";
      section.appendChild(message);
    }
    message.textContent = "No games in this section match the current filters.";
    message.classList.remove("hidden");
    return;
  }

  message?.classList.add("hidden");
}

function updateSection(entry, filters) {
  const { section, count, classification } = entry;
  if (!section) return 0;

  const cards = Array.from(section.querySelectorAll(".game-card"));
  const visibleCards = filteredCards(cards, filters);
  const visibleSet = new Set(visibleCards);

  for (const card of cards) {
    card.classList.toggle("library-card-filtered", !visibleSet.has(card));
  }

  if (count) count.textContent = String(visibleCards.length);

  const filterActive = Boolean(filters.query) || filters.classification !== "all";
  const categorySelected = filters.classification === classification;

  section.dataset.filterActive = filterActive && categorySelected ? "true" : "false";
  section.classList.toggle("library-section-filtered-empty", visibleCards.length === 0);

  setSectionFilterMessage(
    section,
    filterActive && categorySelected && visibleCards.length === 0,
  );

  if (classification === GameLibraryClassification.CANCELLED) {
    const shouldShow =
      cards.length > 0
      || filters.classification === GameLibraryClassification.CANCELLED;
    section.classList.toggle("hidden", !shouldShow);
  }

  return visibleCards.length;
}

export function applyGameLibraryFilters() {
  if (!controls.sections) return;

  const filters = activeFilters();
  const allCards = Array.from(controls.sections.querySelectorAll(".game-card"));
  const total = allCards.length;
  let visible = 0;

  for (const entry of sectionConfig) visible += updateSection(entry, filters);

  const filterActive = Boolean(filters.query) || filters.classification !== "all";

  if (controls.resultStatus) {
    controls.resultStatus.textContent =
      filterActive
        ? `Showing ${visible} of ${total} games`
        : `Showing all ${total} games`;
    controls.resultStatus.dataset.filtered = filterActive ? "true" : "false";
  }

  if (controls.noResults) {
    controls.noResults.classList.toggle("hidden", !filterActive || visible !== 0);
  }

  if (controls.clear) controls.clear.disabled = !filterActive;
}

function clearGameLibraryFilters() {
  if (controls.search) controls.search.value = "";
  if (controls.classification) controls.classification.value = "all";
  applyGameLibraryFilters();
  controls.search?.focus();
}

controls.search?.addEventListener("input", applyGameLibraryFilters);
controls.classification?.addEventListener("change", applyGameLibraryFilters);
controls.clear?.addEventListener("click", clearGameLibraryFilters);

if (controls.sections) {
  let scheduled = false;

  const observer = new MutationObserver(() => {
    if (scheduled) return;
    scheduled = true;

    requestAnimationFrame(() => {
      scheduled = false;
      applyGameLibraryFilters();
    });
  });

  const gameLists = [
    byId("games-live-list"),
    byId("games-upcoming-list"),
    byId("games-completed-list"),
    byId("games-cancelled-list"),
  ].filter(Boolean);

  for (const list of gameLists) {
    observer.observe(list, {
      childList: true,
      subtree: false,
    });
  }
}

applyGameLibraryFilters();
