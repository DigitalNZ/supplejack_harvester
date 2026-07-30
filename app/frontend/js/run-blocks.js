// Behaviour for the "Blocks to run" rows (app/views/pipelines/_run_blocks.html.erb).
//
// Two rules, both of which the server also enforces (RunConfiguration#validate_chain_inputs):
//   - a block that is not running has no input to choose, so its select is disabled
//   - a block whose preceding block is not running cannot take "output of previous
//     block": it needs data prepared by an earlier run, so that option is removed
//     from the choices and a pre-processed-data option is selected instead

const FRESH = "fresh";
const PREPROCESS_OUTPUT = "preprocess_output:";

const rowsIn = (root) =>
  Array.from(root.querySelectorAll('[data-js="run-block-row"]'));

const checkboxIn = (row) => row.querySelector('[data-js="run-block-checkbox"]');

const inputIn = (row) => row.querySelector('[data-js="run-block-input"]');

const firstPreprocessOption = (select) =>
  Array.from(select.options).find((option) =>
    option.value.startsWith(PREPROCESS_OUTPUT)
  );

const setFeedback = (select, message) => {
  const existing = select.parentElement.querySelector(
    '[data-js="run-block-feedback"]'
  );

  if (!message) {
    existing?.remove();
    select.classList.remove("is-invalid");
    return;
  }

  select.classList.add("is-invalid");

  if (existing) {
    existing.textContent = message;
    return;
  }

  const feedback = document.createElement("div");
  feedback.className = "text-danger small mt-1";
  feedback.dataset.js = "run-block-feedback";
  feedback.textContent = message;
  select.parentElement.appendChild(feedback);
};

const refreshRow = (row, previousRow) => {
  const checkbox = checkboxIn(row);
  const select = inputIn(row);

  if (!checkbox || !select) return;

  select.disabled = checkbox.disabled || !checkbox.checked;

  const freshOption = Array.from(select.options).find(
    (option) => option.value === FRESH
  );
  const previousRuns = previousRow && !checkboxIn(previousRow)?.checked;

  if (freshOption) freshOption.hidden = Boolean(previousRuns);

  if (!previousRuns || !checkbox.checked) {
    setFeedback(select, null);
    return;
  }

  if (select.value === FRESH) {
    const preprocessOption = firstPreprocessOption(select);
    if (preprocessOption) select.value = preprocessOption.value;
  }

  setFeedback(
    select,
    select.value === FRESH
      ? "No pre-processed data available for this block yet - run the block before it, or pick an existing extraction."
      : null
  );
};

export const initRunBlocks = (root) => {
  const container = root || document;
  const rows = rowsIn(container);

  if (rows.length === 0) return;

  const refresh = () =>
    rows.forEach((row, index) =>
      refreshRow(row, index > 0 ? rows[index - 1] : null)
    );

  rows.forEach((row) => {
    checkboxIn(row)?.addEventListener("change", refresh);
    inputIn(row)?.addEventListener("change", refresh);
  });

  refresh();
};

initRunBlocks(document);
