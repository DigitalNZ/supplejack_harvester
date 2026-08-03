// Behaviour for the "Blocks to run" rows (app/views/pipelines/_run_blocks.html.erb).
//
// Three rules, all of which the server also enforces (RunConfiguration#validate_chain_inputs):
//   - a run cannot leave a hole in the chain: it starts at some block and continues
//     to the end. Unticking a block therefore unticks everything before it, and
//     ticking one ticks everything after it
//   - a block that is not running has no input or page limit to choose, so both of
//     its fields are disabled
//   - a block whose preceding block is not running cannot take "output of previous
//     block": it needs data prepared by an earlier run, so that option is removed
//     from the choices and a pre-processed-data option is selected instead

const FRESH = "fresh";
const PREPROCESS_OUTPUT = "preprocess_output:";

const rowsIn = (root) =>
  Array.from(root.querySelectorAll('[data-js="run-block-row"]'));

const checkboxIn = (row) => row.querySelector('[data-js="run-block-checkbox"]');

const inputIn = (row) => row.querySelector('[data-js="run-block-input"]');

const pagesIn = (row) => row.querySelector('[data-js="run-block-pages"]');

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
  const pages = pagesIn(row);

  if (!checkbox || !select) return;

  select.disabled = checkbox.disabled || !checkbox.checked;
  if (pages) pages.disabled = select.disabled;

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

// A block that cannot run at all is left alone: its checkbox is disabled, so there
// is nothing to set either way.
const setChecked = (row, checked) => {
  const checkbox = checkboxIn(row);

  if (checkbox && !checkbox.disabled) checkbox.checked = checked;
};

// Keeps the ticked blocks contiguous to the end of the chain. Unticking a block
// means the run no longer reaches it, so the blocks feeding it are pointless;
// ticking one means the run reaches everything after it.
const closeGaps = (rows, index) => {
  if (checkboxIn(rows[index])?.checked) {
    rows.slice(index + 1).forEach((row) => setChecked(row, true));
  } else {
    rows.slice(0, index).forEach((row) => setChecked(row, false));
  }
};

export const initRunBlocks = (root) => {
  const container = root || document;
  const rows = rowsIn(container);

  if (rows.length === 0) return;

  const refresh = () =>
    rows.forEach((row, index) =>
      refreshRow(row, index > 0 ? rows[index - 1] : null)
    );

  rows.forEach((row, index) => {
    checkboxIn(row)?.addEventListener("change", () => {
      closeGaps(rows, index);
      refresh();
    });

    inputIn(row)?.addEventListener("change", refresh);
  });

  refresh();
};

initRunBlocks(document);
