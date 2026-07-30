const pipelinePageTypeSelect = document.getElementById(
  "js-pipeline-page-type-select"
);

if (pipelinePageTypeSelect) {
  const pipelinePageType = document.getElementById("js-pipeline-page-type");
  const pipelinePages = document.getElementById("js-pipeline-pages");
  const pipelinePagesInput = document.getElementById("harvest_job_pages");

  pipelinePageTypeSelect.addEventListener("change", (event) => {
    if (event.target.value == "all_available_pages") {
      pipelinePageType.setAttribute("class", "col-7");
      pipelinePages.setAttribute("class", "col-2 d-none");
      pipelinePagesInput.removeAttribute("required");
    } else if (event.target.value == "set_number") {
      pipelinePageType.setAttribute("class", "col-4");
      pipelinePages.setAttribute("class", "col-3");
      pipelinePagesInput.setAttribute("required", "true");
    }
  });
}
