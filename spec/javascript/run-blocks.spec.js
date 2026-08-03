import { initRunBlocks } from "~/js/run-blocks";

// Mirrors the markup of app/views/pipelines/_run_blocks.html.erb: two chain blocks,
// the second of which can be pointed at an earlier run's pre-processed data.
const render = ({ secondBlockHasStoredOutput = true } = {}) => {
  const storedOutputOption = secondBlockHasStoredOutput
    ? '<option value="preprocess_output:44">Pre-processed data from job #44</option>'
    : "";

  document.body.innerHTML = `
    <div id="js-run-blocks">
      <div data-js="run-block-row" data-position="0">
        <input type="checkbox" data-js="run-block-checkbox" id="first-run" checked>
        <div>
          <select data-js="run-block-input" id="first-input">
            <option value="fresh">Fresh extraction</option>
          </select>
        </div>
      </div>
      <div data-js="run-block-row" data-position="1">
        <input type="checkbox" data-js="run-block-checkbox" id="second-run" checked>
        <div>
          <select data-js="run-block-input" id="second-input">
            <option value="fresh">Output of previous block</option>
            ${storedOutputOption}
            <option value="extraction_job:987">Existing extraction: 987</option>
          </select>
        </div>
      </div>
    </div>
  `;

  initRunBlocks(document.getElementById("js-run-blocks"));

  return {
    firstRun: document.getElementById("first-run"),
    secondInput: document.getElementById("second-input"),
    secondRun: document.getElementById("second-run"),
  };
};

const uncheck = (checkbox) => {
  checkbox.checked = false;
  checkbox.dispatchEvent(new Event("change"));
};

describe("run blocks", () => {
  it("leaves a block on its default input while the block before it runs", () => {
    const { secondInput } = render();

    expect(secondInput.value).toEqual("fresh");
    expect(secondInput.disabled).toBe(false);
  });

  it("disables the input of a block that is not running", () => {
    const { secondRun, secondInput } = render();

    uncheck(secondRun);

    expect(secondInput.disabled).toBe(true);
  });

  it("switches to stored pre-processed data when the block before it is not running", () => {
    const { firstRun, secondInput } = render();

    uncheck(firstRun);

    expect(secondInput.value).toEqual("preprocess_output:44");
    expect(secondInput.querySelector('option[value="fresh"]').hidden).toBe(true);
  });

  it("flags a block that has no data to fall back on", () => {
    const { firstRun, secondInput } = render({ secondBlockHasStoredOutput: false });

    uncheck(firstRun);

    expect(secondInput.classList).toContain("is-invalid");
    expect(document.querySelector('[data-js="run-block-feedback"]').textContent).toContain(
      "No pre-processed data available"
    );
  });
});
