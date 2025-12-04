document.addEventListener("DOMContentLoaded", function () {
  // Handle harvest modal
  const preExtractionToggle = document.getElementById("js-pre-extraction-toggle");
  const preExtractionDepthField = document.querySelector('input[name="extraction_definition[pre_extraction_depth]"]');
  const linkSelectorsContainer = document.getElementById("js-link-selectors-container");

  if (preExtractionToggle) {
    function updateLinkSelectorFields() {
      const isPreExtraction = preExtractionToggle.value === "true";
      const depth = parseInt(preExtractionDepthField?.value || 1, 10) || 1;

      if (linkSelectorsContainer) {
        if (isPreExtraction) {
          linkSelectorsContainer.classList.remove("d-none");
          // Show/hide fields based on depth
          for (let i = 1; i <= 10; i++) { // Support up to 10 levels
            const levelFields = linkSelectorsContainer.querySelectorAll(`.js-link-selector-level-${i}`);
            levelFields.forEach(function(field) {
              if (i <= depth) {
                field.classList.remove("d-none");
              } else {
                field.classList.add("d-none");
              }
            });
          }
        } else {
          linkSelectorsContainer.classList.add("d-none");
        }
      }
    }

    preExtractionToggle.addEventListener("change", updateLinkSelectorFields);
    if (preExtractionDepthField) {
      preExtractionDepthField.addEventListener("change", updateLinkSelectorFields);
      preExtractionDepthField.addEventListener("input", updateLinkSelectorFields);
    }
    updateLinkSelectorFields(); // Run on page load
  }

  // Handle enrichment modals (multiple modals with IDs)
  document.querySelectorAll('[id^="js-pre-extraction-toggle-"]').forEach(function(toggle) {
    const enrichmentId = toggle.id.replace("js-pre-extraction-toggle-", "");
    const container = document.getElementById(`js-link-selectors-container-${enrichmentId}`);
    // Find depth field within the same form/modal
    const form = toggle.closest('form');
    const depthField = form ? form.querySelector('input[name="extraction_definition[pre_extraction_depth]"]') : null;

    if (toggle && container) {
      function updateEnrichmentLinkSelectorFields() {
        const isPreExtraction = toggle.value === "true";
        const depth = parseInt(depthField?.value || 1, 10) || 1;

        if (isPreExtraction) {
          container.classList.remove("d-none");
          // Show/hide fields based on depth
          for (let i = 1; i <= 10; i++) {
            const levelFields = container.querySelectorAll(`.js-link-selector-level-${i}`);
            levelFields.forEach(function(field) {
              if (i <= depth) {
                field.classList.remove("d-none");
              } else {
                field.classList.add("d-none");
              }
            });
          }
        } else {
          container.classList.add("d-none");
        }
      }

      toggle.addEventListener("change", updateEnrichmentLinkSelectorFields);
      if (depthField) {
        depthField.addEventListener("change", updateEnrichmentLinkSelectorFields);
        depthField.addEventListener("input", updateEnrichmentLinkSelectorFields);
      }
      updateEnrichmentLinkSelectorFields();
    }
  });
});

