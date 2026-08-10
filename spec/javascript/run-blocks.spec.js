import { initRunBlocks } from "~/js/run-blocks";

// Mirrors the markup of app/views/pipelines/_run_block_row.html.erb. Rows after the
// first can be pointed at an earlier run's pre-processed data.
const rowMarkup = (index, storedOutput) => `
  <div data-js="run-block-row" data-position="${index}">
    <input type="checkbox" data-js="run-block-checkbox" id="run-${index}" checked>
    <div>
      <select data-js="run-block-input" id="input-${index}">
        <option value="fresh">${index === 0 ? "Fresh extraction" : "Output of previous block"}</option>
        ${storedOutput ? '<option value="preprocess_output:44">Pre-processed data from job #44</option>' : ""}
        <option value="extraction_job:987">Existing extraction: 987</option>
      </select>
      <input type="number" data-js="run-block-pages" id="pages-${index}">
    </div>
  </div>
`;

const render = ({ rows = 2, storedOutput = true } = {}) => {
  document.body.innerHTML = `
    <div id="js-run-blocks">
      ${Array.from({ length: rows }, (_, index) => rowMarkup(index, storedOutput && index > 0)).join("")}
    </div>
  `;

  initRunBlocks(document.getElementById("js-run-blocks"));
};

const checkbox = (index) => document.getElementById(`run-${index}`);
const input = (index) => document.getElementById(`input-${index}`);
const pages = (index) => document.getElementById(`pages-${index}`);

const toggle = (index) => {
  const box = checkbox(index);
  box.checked = !box.checked;
  box.dispatchEvent(new Event("change"));
};

describe("run blocks", () => {
  it("leaves a block on its default input while the block before it runs", () => {
    render();

    expect(input(1).value).toEqual("fresh");
    expect(input(1).disabled).toBe(false);
  });

  it("disables the input and page limit of a block that is not running", () => {
    render();

    toggle(1);

    expect(input(1).disabled).toBe(true);
    expect(pages(1).disabled).toBe(true);
  });

  it("enables the page limit of a block that is running", () => {
    render();

    expect(pages(1).disabled).toBe(false);
  });

  it("switches to stored pre-processed data when the block before it is not running", () => {
    render();

    toggle(0);

    expect(input(1).value).toEqual("preprocess_output:44");
    expect(input(1).querySelector('option[value="fresh"]').hidden).toBe(true);
  });

  it("flags a block that has no data to fall back on", () => {
    render({ storedOutput: false });

    toggle(0);

    expect(input(1).classList).toContain("is-invalid");
    expect(
      document.querySelector('[data-js="run-block-feedback"]').textContent
    ).toContain("No pre-processed data available");
  });

  // A run covers one unbroken stretch of the chain: it may start late and stop early,
  // but it may never skip a block and run a later one.
  describe("keeping the chain contiguous", () => {
    const state = () => [0, 1, 2].map((index) => checkbox(index).checked);

    it("stops the run at a block that is unticked", () => {
      render({ rows: 3 });

      toggle(1);

      expect(state()).toEqual([true, false, false]);
    });

    it("leaves only the first block running when the second is unticked", () => {
      render({ rows: 3 });

      toggle(1);

      expect(checkbox(0).checked).toBe(true);
      expect(input(0).disabled).toBe(false);
      expect(input(1).disabled).toBe(true);
    });

    it("keeps a run that starts late", () => {
      render({ rows: 3 });

      toggle(0);

      expect(state()).toEqual([false, true, true]);
    });

    it("fills in a block that would otherwise be skipped over", () => {
      render({ rows: 3 });

      // Leave only the first block running, then tick the last one: the middle block
      // has to come with it, or it would have nothing to read.
      toggle(1);
      expect(state()).toEqual([true, false, false]);

      toggle(2);

      expect(state()).toEqual([true, true, true]);
    });
  });
});
