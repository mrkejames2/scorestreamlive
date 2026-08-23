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

    const brand = document.createElement("span");
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

    const role = document.createElement("span");
    role.className = "ssl-nav-role";
    role.textContent = user.club_role || "";

    const account = document.createElement("a");
    account.href = "/account";
    account.className = "ssl-nav-user";
    account.textContent = user.display_name || user.email;

    const logout = document.createElement("button");
    logout.type = "button";
    logout.textContent = "Logout";
    logout.addEventListener("click", async () => {
      logout.disabled = true;
      try {
        await fetch("/logout", { method: "POST" });
      } finally {
        window.location.href = "/login";
      }
    });

    bar.append(brand, clubName, games, teams, role, account, logout);

    const main = document.querySelector("main");
    if (main) document.body.insertBefore(bar, main);
    else document.body.prepend(bar);
  } catch (error) {
    console.debug("Authenticated navigation unavailable", error);
  }
})();
