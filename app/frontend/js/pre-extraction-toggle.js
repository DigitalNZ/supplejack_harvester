document.addEventListener("DOMContentLoaded", function () {
  const preExtractionToggle = document.getElementById("js-pre-extraction-toggle");
  const linkSelectorFields = document.querySelectorAll(".js-link-selector");

  if (preExtractionToggle) {
    function toggleLinkSelector() {
      const isPreExtraction = preExtractionToggle.value === "true";
      linkSelectorFields.forEach(function(field) {
        if (isPreExtraction) {
          field.classList.remove("d-none");
        } else {
          field.classList.add("d-none");
        }
      });
    }

    preExtractionToggle.addEventListener("change", toggleLinkSelector);
    toggleLinkSelector(); // Run on page load
  }
});

