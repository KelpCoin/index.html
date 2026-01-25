(() => {
  const configUrl = "store_config.json";
  const exampleConfigUrl = "store_config.example.json";
  const apiUrl = "/api/skus";
  const fallbackIndexUrl = "skus_index.json";

  const state = {
    config: null,
    skus: [],
    tags: new Set(),
    selectedTag: null,
    search: "",
    auctionsOnly: false,
    bundleOnly: false,
    stripe: null
  };

  const elements = {
    title: document.getElementById("store-title"),
    status: document.getElementById("store-status"),
    grid: document.getElementById("sku-grid"),
    template: document.getElementById("sku-card-template"),
    tagBar: document.getElementById("tag-bar"),
    searchInput: document.getElementById("search-input"),
    toggleAuctions: document.getElementById("toggle-auctions"),
    toggleInstock: document.getElementById("toggle-instock")
  };

  function formatPrice(nzd) {
    if (typeof nzd !== "number") {
      return "NZD ?";
    }
    return `NZD ${nzd.toFixed(2)}`;
  }

  function safeText(text) {
    if (!text) return "";
    return String(text);
  }

  function buildPayPalLink(handle, price) {
    const safeHandle = handle || "Hornbag666";
    const amount = typeof price === "number" ? price.toFixed(2) : "";
    const url = `https://www.paypal.com/paypalme/${encodeURIComponent(safeHandle)}`;
    return amount ? `${url}/${amount}` : url;
  }

  function updateStatus() {
    if (state.skus.length === 0) {
      elements.status.textContent = "No SKUs found (showing featured packs)";
    } else {
      elements.status.textContent = "Live inventory from Cortex";
    }
  }

  function renderTags() {
    elements.tagBar.innerHTML = "";
    if (state.tags.size === 0) return;
    const allTag = document.createElement("button");
    allTag.className = `tag ${state.selectedTag ? "" : "active"}`;
    allTag.textContent = "All";
    allTag.addEventListener("click", () => {
      state.selectedTag = null;
      render();
    });
    elements.tagBar.appendChild(allTag);

    [...state.tags].sort().forEach((tag) => {
      const tagBtn = document.createElement("button");
      tagBtn.className = `tag ${state.selectedTag === tag ? "active" : ""}`;
      tagBtn.textContent = tag;
      tagBtn.addEventListener("click", () => {
        state.selectedTag = tag;
        render();
      });
      elements.tagBar.appendChild(tagBtn);
    });
  }

  function filterSkus(skus) {
    return skus.filter((sku) => {
      const query = state.search.toLowerCase();
      const matchesSearch = !query || [sku.sku_id, sku.name, sku.description, ...(sku.tags || [])]
        .join(" ")
        .toLowerCase()
        .includes(query);

      const matchesTag = !state.selectedTag || (sku.tags || []).includes(state.selectedTag);
      const matchesAuction = !state.auctionsOnly || !!sku.auction;
      const matchesBundle = !state.bundleOnly || (sku.bundle_files && sku.bundle_files.length > 0);

      return matchesSearch && matchesTag && matchesAuction && matchesBundle;
    });
  }

  function renderVideo(container, sku) {
    container.innerHTML = "";
    if (!sku.mr_onion_video_url) return;
    const video = document.createElement("video");
    video.src = sku.mr_onion_video_url;
    video.controls = true;
    video.muted = true;
    video.playsInline = true;
    video.preload = "metadata";
    video.addEventListener("click", () => {
      if (video.muted) {
        video.muted = false;
        video.volume = 0.6;
      }
    });
    container.appendChild(video);
  }

  function renderAuction(panel, auction) {
    panel.innerHTML = "";
    if (!auction) return;
    const title = document.createElement("h3");
    title.textContent = "Auction live";
    const highest = document.createElement("p");
    const bidders = (auction.bidders || []).slice().sort((a, b) => (b.amount || 0) - (a.amount || 0));
    const topBidder = bidders[0];
    highest.textContent = topBidder
      ? `Highest bid: NZD ${topBidder.amount} by ${topBidder.user}`
      : "No bids yet";
    const countdown = document.createElement("p");
    countdown.className = "countdown";
    const bidEnd = auction.bid_end_utc ? new Date(auction.bid_end_utc) : null;
    countdown.textContent = bidEnd ? `Ends: ${bidEnd.toUTCString()}` : "End time unknown";

    const list = document.createElement("ul");
    bidders.forEach((bid) => {
      const item = document.createElement("li");
      item.textContent = `${bid.user}: NZD ${bid.amount}`;
      list.appendChild(item);
    });

    const button = document.createElement("button");
    button.className = "btn secondary";
    button.textContent = "Place Bid";
    button.type = "button";
    button.disabled = true;

    panel.appendChild(title);
    panel.appendChild(highest);
    panel.appendChild(countdown);
    if (bidders.length > 0) {
      panel.appendChild(list);
    }
    panel.appendChild(button);

    if (bidEnd) {
      setInterval(() => {
        const now = new Date();
        const diff = bidEnd.getTime() - now.getTime();
        if (diff <= 0) {
          countdown.textContent = "Auction ended";
          return;
        }
        const hours = Math.floor(diff / 3600000);
        const mins = Math.floor((diff % 3600000) / 60000);
        const secs = Math.floor((diff % 60000) / 1000);
        countdown.textContent = `Ends in ${hours}h ${mins}m ${secs}s UTC`;
      }, 1000);
    }
  }

  function renderSkus(skus) {
    elements.grid.innerHTML = "";
    skus.forEach((sku) => {
      const node = elements.template.content.cloneNode(true);
      const card = node.querySelector(".card");
      node.querySelector(".sku-name").textContent = safeText(sku.name || "Unnamed");
      node.querySelector(".sku-id").textContent = safeText(sku.sku_id || "SKU-UNKNOWN");
      node.querySelector(".price").textContent = formatPrice(sku.price_nzd);
      node.querySelector(".sku-description").textContent = safeText(sku.description || "");

      renderVideo(node.querySelector(".video-wrap"), sku);

      const stripeBtn = node.querySelector(".stripe-btn");
      const paypalBtn = node.querySelector(".paypal-btn");
      const bundleBtn = node.querySelector(".bundle-btn");
      const fulfillment = node.querySelector(".fulfillment");

      if (state.stripe && sku.stripe_price_id) {
        stripeBtn.disabled = false;
        stripeBtn.addEventListener("click", () => {
          state.stripe.redirectToCheckout({
            lineItems: [{ price: sku.stripe_price_id, quantity: 1 }],
            mode: "payment",
            successUrl: `${location.origin}/success.html?sku=${encodeURIComponent(sku.sku_id)}`,
            cancelUrl: `${location.origin}/store.html?canceled=1`
          });
        });
      } else {
        stripeBtn.disabled = true;
        stripeBtn.classList.add("disabled");
        stripeBtn.textContent = "Card checkout unavailable";
      }

      paypalBtn.addEventListener("click", () => {
        window.open(buildPayPalLink(sku.paypal_handle, sku.price_nzd), "_blank", "noopener");
      });

      if (sku.bundle_files && sku.bundle_files.length > 0) {
        const bundle = sku.bundle_files[0];
        bundleBtn.disabled = false;
        bundleBtn.addEventListener("click", () => {
          window.open(bundle.url, "_blank", "noopener");
        });
        fulfillment.textContent = `Bundle ready: ${bundle.name}`;
      } else {
        bundleBtn.disabled = true;
        bundleBtn.classList.add("disabled");
        bundleBtn.textContent = "No bundle";
        fulfillment.textContent = "Fulfillment via email after purchase";
      }

      const tagsWrap = node.querySelector(".tags");
      tagsWrap.innerHTML = "";
      (sku.tags || []).forEach((tag) => {
        const chip = document.createElement("span");
        chip.className = "tag-chip";
        chip.textContent = tag;
        tagsWrap.appendChild(chip);
      });

      const lastUpdated = node.querySelector(".last-updated");
      if (sku.last_updated_utc) {
        const date = new Date(sku.last_updated_utc);
        lastUpdated.textContent = `Last updated: ${date.toUTCString()}`;
      } else {
        lastUpdated.textContent = "";
      }

      renderAuction(node.querySelector(".auction-panel"), sku.auction);

      const infoToggle = node.querySelector(".info-toggle");
      infoToggle.addEventListener("click", () => {
        card.classList.toggle("expanded");
      });

      elements.grid.appendChild(node);
    });
  }

  function renderFeatured() {
    const featured = [
      {
        sku_id: "FEATURED-AYULA",
        name: "Kookus Crusty Commander: Ayula Fight Club Loops",
        description: "A punchy Ayula plan that stacks fight triggers into repeatable value. You get a tight combo map, clean mulligan heuristics, and a line-by-line guide on how to win without cEDH cringe.",
        price_nzd: null,
        stripe_price_id: null,
        tags: ["Commander", "Ayula", "Bear Fight"],
        paypal_handle: "Hornbag666"
      },
      {
        sku_id: "FEATURED-GY",
        name: "Grease Goblin GY Value Pack: Cheap recursion that feels illegal",
        description: "A set of primers for budget graveyard engines, a recursion checklist, and a price sheet that calls out the steals. Built for steady pressure without premium staples.",
        price_nzd: null,
        stripe_price_id: null,
        tags: ["Commander", "Graveyard", "Budget"],
        paypal_handle: "Hornbag666"
      },
      {
        sku_id: "FEATURED-NZ",
        name: "NZ Deck Flip Safety Kit: Pricing, risk, and shipping sanity for Commander sellers",
        description: "Spreadsheets plus checklists for pricing, risk control, and shipping discipline. Built for sellers who want margin without the chaos.",
        price_nzd: null,
        stripe_price_id: null,
        tags: ["Commander", "Seller Ops", "NZ"],
        paypal_handle: "Hornbag666"
      }
    ];

    renderSkus(featured.map((sku) => ({
      ...sku,
      description: `${sku.description} (Featured concept pack)`
    })));
  }

  function render() {
    updateStatus();
    renderTags();
    const filtered = filterSkus(state.skus);
    if (state.skus.length === 0) {
      renderFeatured();
    } else if (filtered.length === 0) {
      elements.grid.innerHTML = "<p>No matches. Adjust filters.</p>";
    } else {
      renderSkus(filtered);
    }
  }

  async function loadConfig() {
    try {
      const res = await fetch(configUrl, { cache: "no-store" });
      if (!res.ok) throw new Error("Config not found");
      return await res.json();
    } catch (err) {
      const res = await fetch(exampleConfigUrl, { cache: "no-store" });
      return await res.json();
    }
  }

  async function loadSkus() {
    try {
      const res = await fetch(apiUrl, { cache: "no-store" });
      if (!res.ok) throw new Error("API not available");
      return await res.json();
    } catch (err) {
      const res = await fetch(fallbackIndexUrl, { cache: "no-store" });
      if (!res.ok) {
        return [];
      }
      return await res.json();
    }
  }

  function collectTags(skus) {
    state.tags.clear();
    skus.forEach((sku) => {
      (sku.tags || []).forEach((tag) => state.tags.add(tag));
    });
  }

  function setupListeners() {
    elements.searchInput.addEventListener("input", (event) => {
      state.search = event.target.value || "";
      render();
    });
    elements.toggleAuctions.addEventListener("change", (event) => {
      state.auctionsOnly = event.target.checked;
      render();
    });
    elements.toggleInstock.addEventListener("change", (event) => {
      state.bundleOnly = event.target.checked;
      render();
    });
  }

  async function init() {
    state.config = await loadConfig();
    if (state.config && state.config.store_title) {
      elements.title.textContent = state.config.store_title;
      document.title = state.config.store_title;
    }

    if (state.config && state.config.stripe_publishable_key) {
      state.stripe = Stripe(state.config.stripe_publishable_key);
    }

    const skus = await loadSkus();
    state.skus = Array.isArray(skus) ? skus : [];
    collectTags(state.skus);
    setupListeners();
    render();
  }

  init();
})();
