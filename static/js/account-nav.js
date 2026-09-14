(async () => {
  try {
    const response = await fetch("/api/auth/me", {
      cache: "no-store",
    });

    if (!response.ok) return;

    const user = await response.json();

    let club = null;

    try {
      const clubResponse = await fetch(
        "/api/clubs/current",
        { cache: "no-store" },
      );

      if (clubResponse.ok) {
        club = await clubResponse.json();
      }
    } catch {}


    /*
     * M18-G3:
     * Resolve the same authoritative effective Club branding used
     * by the public overlay/broadcast surfaces.
     *
     * This endpoint is intentionally available to any authenticated
     * Club member. Editing branding remains Director-only.
     */
    let branding = null;

    try {
      const brandingResponse = await fetch(
        "/api/account/effective-branding",
        { cache: "no-store" },
      );

      if (brandingResponse.ok) {
        branding = await brandingResponse.json();
      }
    } catch {}


    const hasClubBranding = Boolean(
      branding?.enabled
    );


    const bar = document.createElement("nav");

    bar.className = "ssl-account-nav";

    bar.setAttribute(
      "aria-label",
      "Authenticated navigation",
    );


    /*
     * Tenant / Club identity
     */
    const brand = document.createElement("a");

    brand.href = "/games";

    brand.className = "ssl-nav-brand";


    if (hasClubBranding) {
      brand.classList.add("has-club-branding");
    }


    /*
     * Optional Club logo.
     */
    if (
      hasClubBranding &&
      branding?.logo_url
    ) {
      const brandLogo = document.createElement("img");

      brandLogo.className = "ssl-nav-club-logo";

      brandLogo.src = branding.logo_url;

      brandLogo.alt =
        `${branding.display_name || "Club"} logo`;

      brandLogo.addEventListener(
        "error",
        () => {
          brandLogo.remove();

          brand.classList.remove(
            "has-club-logo",
          );
        },
      );

      brand.classList.add("has-club-logo");

      brand.append(brandLogo);
    }


    /*
     * Main identity line.
     *
     * Premium configured:
     *   Saginaw Area Futsal League
     *
     * Fallback:
     *   ScoreStreamLive
     */
    const brandTitle = document.createElement("span");

    brandTitle.className = "ssl-nav-brand-title";

    brandTitle.textContent = hasClubBranding
      ? (
          branding.display_name ||
          branding.short_name ||
          club?.name ||
          "Club"
        )
      : "ScoreStreamLive";

    brand.append(brandTitle);


    /*
     * Secondary identity.
     *
     * Premium configured:
     *   SAFL
     *
     * Fallback:
     *   underlying Club name
     */
    const clubName = document.createElement("span");

    clubName.className = "ssl-nav-club";

    if (hasClubBranding) {
      clubName.textContent =
        branding.short_name ||
        club?.name ||
        "Club";
    } else {
      clubName.textContent =
        club?.name ||
        "Club";
    }


    /*
     * Small platform attribution when Club branding is active.
     */
    let poweredBy = null;

    if (hasClubBranding) {
      poweredBy = document.createElement("span");

      poweredBy.className = "ssl-nav-powered-by";

      poweredBy.textContent =
        "Powered by ScoreStreamLive";
    }


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

    account.className =
      "ssl-nav-link ssl-nav-account";

    account.textContent =
      user.club_role === "DIRECTOR"
        ? "Club Admin"
        : "Account";


    const identity = document.createElement("span");

    identity.className = "ssl-nav-identity";


    const identityName =
      document.createElement("strong");

    identityName.textContent =
      user.display_name ||
      user.email;


    const role = document.createElement("span");

    role.className = "ssl-nav-role";

    role.textContent =
      user.club_role ||
      "";


    identity.append(
      identityName,
      role,
    );


    const logout =
      document.createElement("button");

    logout.type = "button";

    logout.className = "ssl-nav-logout";

    logout.textContent = "Logout";


    logout.addEventListener(
      "click",
      async () => {
        logout.disabled = true;

        try {
          await fetch(
            "/logout",
            { method: "POST" },
          );
        } finally {
          window.location.href = "/login";
        }
      },
    );


    function markActive(
      link,
      active,
    ) {
      link.classList.toggle(
        "active",
        active,
      );

      if (active) {
        link.setAttribute(
          "aria-current",
          "page",
        );
      } else {
        link.removeAttribute(
          "aria-current",
        );
      }
    }


    const path =
      window.location.pathname ||
      "/";


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


    markActive(
      games,
      gamesActive,
    );

    markActive(
      teams,
      teamsActive,
    );

    markActive(
      account,
      accountActive,
    );


    bar.append(
      brand,
      clubName,
    );

    if (poweredBy) {
      bar.append(poweredBy);
    }

    bar.append(
      games,
      teams,
      account,
      identity,
      logout,
    );


    const main =
      document.querySelector("main");


    if (main) {
      document.body.insertBefore(
        bar,
        main,
      );
    } else {
      document.body.prepend(bar);
    }

  } catch (error) {
    console.debug(
      "Authenticated navigation unavailable",
      error,
    );
  }
})();
