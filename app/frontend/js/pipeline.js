const pipelinePageTypeSelect = document.getElementById(
  "js-pipeline-page-type-select"
);

if (pipelinePageTypeSelect) {
  const pipelinePageType = document.getElementById("js-pipeline-page-type");
  const pipelinePages = document.getElementById("js-pipeline-pages");
  // The field is rendered by a form_with model: PipelineJob (see
  // app/views/pipelines/_run_pipeline.html.erb), so its id is pipeline_job_pages.
  // Nothing has ever been called harvest_job_pages, so this lookup returned null and
  // both branches below threw before they could set the required attribute.
  const pipelinePagesInput = document.getElementById("pipeline_job_pages");

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
