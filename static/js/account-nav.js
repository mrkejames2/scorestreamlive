(async () => {
  try {
    const response = await fetch("/api/auth/me", { cache: "no-store" });
    if (!response.ok) return;
    const user = await response.json();

    let club = null;
    try {
      const clubResponse = await fetch("/api/clubs/current", { cache: "no-store" });
      if (clubResponse.ok) club = await clubResponse.json();
    } catch {}

    const bar = document.createElement("nav");
    bar.className = "ssl-account-nav";
    bar.setAttribute("aria-label", "Authenticated navigation");

    const brand = document.createElement("a");
    brand.href = "/games";
    brand.className = "ssl-nav-brand";
    brand.textContent = "SCORESTREAMLIVE";

    const clubName = document.createElement("span");
    clubName.className = "ssl-nav-club";
    clubName.textContent = club?.name || "Club";

    const games = document.createElement("a");
    games.href = "/games";
    games.className = "ssl-nav-link";
    games.textContent = "Games";

    const teams = document.createElement("a");
    teams.href = "/teams";
    teams.className = "ssl-nav-link";
    teams.textContent = "Teams";

    const account = document.createElement("a");
    account.href = "/account";
    account.className = "ssl-nav-link ssl-nav-account";
    account.textContent = user.club_role === "DIRECTOR" ? "Club Admin" : "Account";

    const identity = document.createElement("span");
    identity.className = "ssl-nav-identity";

    const identityName = document.createElement("strong");
    identityName.textContent = user.display_name || user.email;

    const role = document.createElement("span");
    role.className = "ssl-nav-role";
    role.textContent = user.club_role || "";

    identity.append(identityName, role);

    const logout = document.createElement("button");
    logout.type = "button";
    logout.className = "ssl-nav-logout";
    logout.textContent = "Logout";
    logout.addEventListener("click", async () => {
      logout.disabled = true;
      try {
        await fetch("/logout", { method: "POST" });
      } finally {
        window.location.href = "/login";
      }
    });

    function markActive(link, active) {
      link.classList.toggle("active", active);
      if (active) link.setAttribute("aria-current", "page");
      else link.removeAttribute("aria-current");
    }

    const path = window.location.pathname || "/";

    // Keep the top-level navigation coherent across child workflows.
    // Game detail/setup/control/summary/broadcast are all part of Games.
    const gamesActive =
      path === "/games" ||
      path.startsWith("/games/") ||
      path.startsWith("/control/") ||
      path.startsWith("/summary/") ||
      path.startsWith("/broadcast/");

    const teamsActive =
      path === "/teams" ||
      path.startsWith("/teams/");

    const accountActive =
      path === "/account" ||
      path.startsWith("/account/");

    markActive(games, gamesActive);
    markActive(teams, teamsActive);
    markActive(account, accountActive);

    bar.append(brand, clubName, games, teams, account, identity, logout);

    const main = document.querySelector("main");
    if (main) document.body.insertBefore(bar, main);
    else document.body.prepend(bar);
  } catch (error) {
    console.debug("Authenticated navigation unavailable", error);
  }
})();
