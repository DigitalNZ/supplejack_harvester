import { each } from "lodash";

const enrichmentExtractionFormatSelects = document.getElementsByClassName(
  "js-enrichment-format-select"
);

if (enrichmentExtractionFormatSelects.length != 0) {
  each(enrichmentExtractionFormatSelects, (element) => {
    element.addEventListener("change", (event) => {
      toggleEnrichmentEvaluateJavascriptElements(
        event.target.dataset.enrichmentDefinitionId,
        event.target.value
      );
    });
  });

  each(enrichmentExtractionFormatSelects, (element) => {
    toggleEnrichmentEvaluateJavascriptElements(
      element.dataset.enrichmentDefinitionId,
      element.value
    );
  });

  function toggleEnrichmentEvaluateJavascriptElements(id, format) {
    const elements = document.getElementsByClassName("js-evaluate-js-" + id);

    if (format == "HTML") {
      each(elements, (element) => {
        element.classList.remove("d-none");
      });
    } else {
      each(elements, (element) => {
        element.classList.add("d-none");
      });
    }
  }
}
