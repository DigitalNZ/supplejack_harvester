document.addEventListener("DOMContentLoaded", function () {
  const stepTypeSelect = document.querySelector(
    'select[name="automation_step_template[step_type]"]'
  );

  if (stepTypeSelect) {
    const pipelineFields = document.getElementById("pipeline-fields");
    const apiCallFields = document.getElementById("api-call-fields");
    const preExtractionFields = document.getElementById(
      "pre-extraction-fields"
    );
    const pipelineSelect = document.querySelector(
      'select[name="automation_step_template[pipeline_id]"]'
    );

    // Handle step type changes
    stepTypeSelect.addEventListener("change", function () {
      // Hide all fields first
      pipelineFields.classList.add("d-none");
      apiCallFields.classList.add("d-none");
      preExtractionFields.classList.add("d-none");
      pipelineSelect.required = false;

      if (this.value === "pipeline") {
        pipelineFields.classList.remove("d-none");
        pipelineSelect.required = true;
      } else if (this.value === "api_call") {
        apiCallFields.classList.remove("d-none");
      } else if (this.value === "pre_extraction") {
        preExtractionFields.classList.remove("d-none");
      }
    });
  }
});
