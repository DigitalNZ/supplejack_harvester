import { initLoadDefinitionFields } from "~/js/load-definition-fields";

// Mirrors app/views/load_definitions/_fields.html.erb for a harvest block, which is the only
// kind offered a choice of fragment. The priority starts fixed at 0, as it is rendered for a
// new definition defaulting to the primary fragment.
const render = ({ kind = "primary_fragment", priority = "0" } = {}) => {
  document.body.innerHTML = `
    <form>
      <select data-js="load-kind" id="kind">
        <option value="primary_fragment">Standard</option>
        <option value="secondary_fragment">Secondary fragment</option>
      </select>
      <input type="number" data-js="load-priority" id="priority"
             class="${kind === "primary_fragment" ? "form-control-plaintext" : "form-control"}"
             value="${priority}" ${kind === "primary_fragment" ? "readonly" : ""}>
    </form>
  `;

  document.getElementById("kind").value = kind;

  initLoadDefinitionFields(document);
};

const priority = () => document.getElementById("priority");

const choose = (kind) => {
  const select = document.getElementById("kind");
  select.value = kind;
  select.dispatchEvent(new Event("change"));
};

describe("load definition fields", () => {
  it("moves a priority of 0 off the primary fragment's when a secondary one is chosen", () => {
    render();

    choose("secondary_fragment");

    expect(priority().value).toEqual("-1");
  });

  it("gives a blank priority a number too, 0 not being the only value it cannot keep", () => {
    render({ priority: "" });

    choose("secondary_fragment");

    expect(priority().value).toEqual("-1");
  });

  // -1 is a starting point, not the answer: a fragment already sitting below others stays
  // where it was put.
  it("leaves a priority that has already been chosen alone", () => {
    render({ kind: "secondary_fragment", priority: "-4" });

    choose("secondary_fragment");

    expect(priority().value).toEqual("-4");
  });

  it("fixes the priority back at 0 when the block goes back to writing the record itself", () => {
    render({ kind: "secondary_fragment", priority: "-4" });

    choose("primary_fragment");

    expect(priority().value).toEqual("0");
    expect(priority().readOnly).toBe(true);
    expect(priority().className).toEqual("form-control-plaintext");
  });

  it("hands the priority back to the user when it is theirs to choose", () => {
    render();

    choose("secondary_fragment");

    expect(priority().readOnly).toBe(false);
    expect(priority().className).toEqual("form-control");
  });
});
