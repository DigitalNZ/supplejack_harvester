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

  it("disables the input of a block that is not running", () => {
    render();

    toggle(1);

    expect(input(1).disabled).toBe(true);
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

  // A run starts at some block and continues to the end of the chain, so the ticked
  // blocks always stay contiguous.
  describe("keeping the chain contiguous", () => {
    it("unticks the blocks before one that is unticked", () => {
      render({ rows: 3 });

      toggle(1);

      expect(checkbox(0).checked).toBe(false);
      expect(checkbox(1).checked).toBe(false);
      expect(checkbox(2).checked).toBe(true);
    });

    it("ticks the blocks after one that is ticked", () => {
      render({ rows: 3 });

      // Untick from the front, leaving only the last block running.
      toggle(0);
      toggle(1);
      expect([0, 1, 2].map((index) => checkbox(index).checked)).toEqual([
        false,
        false,
        true,
      ]);

      // Ticking the first block again has to bring the rest of the chain with it.
      toggle(0);

      expect([0, 1, 2].map((index) => checkbox(index).checked)).toEqual([
        true,
        true,
        true,
      ]);
    });

    it("leaves the last block alone when it is the only one running", () => {
      render({ rows: 3 });

      toggle(1);

      expect(checkbox(2).checked).toBe(true);
      expect(input(2).disabled).toBe(false);
    });
  });
});
