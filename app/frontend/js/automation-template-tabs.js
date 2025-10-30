// Ensure Bootstrap JS is available
import { Tab } from "bootstrap";

// Works with both plain loads and Turbo
const onLoad = () => {
  // 1) Activate tab from current hash, if present
  const { hash } = window.location;
  if (hash) {
    const trigger = document.querySelector(
      `a[data-bs-toggle="tab"][href="${CSS.escape(hash)}"]`
    );
    if (trigger) new Tab(trigger).show();
  }

  // 2) Keep the URL hash in sync when user switches tabs
  document.querySelectorAll('a[data-bs-toggle="tab"]').forEach((el) => {
    el.addEventListener("shown.bs.tab", (e) => {
      const newHash = e.target.getAttribute("href");
      // Use replaceState to avoid growing history, or pushState if you prefer back/forward per tab
      history.replaceState(null, "", newHash);
    });
  });
};

document.addEventListener("DOMContentLoaded", onLoad);
document.addEventListener("turbo:load", onLoad); // if using Turbo
