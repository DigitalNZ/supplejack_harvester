document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.getElementById("js-pre-extraction-toggle");
  const depthField = document.querySelector('input[name="extraction_definition[pre_extraction_depth]"]');
  const container = document.getElementById("js-link-selectors-container");

  if (!toggle || !container) return;

  const el = (tag, attrs = {}, children = []) => {
    const element = document.createElement(tag);
    Object.entries(attrs).forEach(([k, v]) => k === "className" ? element.className = v : element.setAttribute(k, v));
    children.forEach(c => element.append(c));
    return element;
  };

  const TOOLTIP = "JSONPath (starts with $) or XPath (starts with / or //) selector to extract links.";

  const createField = (level, value = "") => {
    const levelClass = `js-link-selector-level js-link-selector-level-${level}`;
    const placeholder = level === 1 ? "$.urls[*] or //loc" : `Level ${level} selector`;

    const labelCol = el("div", { className: `col-4 ${levelClass}` }, [
      el("label", { className: "form-label", for: `js-link-selector-${level}` }, [
        `Link Selector Level ${level} `,
        el("span", { "data-bs-toggle": "tooltip", "data-bs-title": TOOLTIP }, [
          el("i", { className: "bi bi-question-circle", "aria-label": "helper text" })
        ])
      ])
    ]);

    const inputCol = el("div", { className: `col-8 ${levelClass}` }, [
      el("input", {
        type: "text",
        name: `extraction_definition[link_selector_${level}]`,
        id: `js-link-selector-${level}`,
        className: "form-control",
        value,
        placeholder
      }),
      el("small", { className: "form-text text-muted" }, ["JSONPath (JSON) or XPath (HTML/XML). Leave blank for default."])
    ]);

    return [labelCol, inputCol];
  };

  const getExistingValues = (maxDepth) => {
    const values = {};
    for (let i = 1; i <= maxDepth; i++) {
      const input = document.getElementById(`js-link-selector-${i}`);
      if (input) values[i] = input.value;
    }
    return values;
  };

  const updateFields = () => {
    const isEnabled = toggle.value === "true";
    container.classList.toggle("d-none", !isEnabled);

    if (!isEnabled) return;

    const depth = parseInt(depthField?.value, 10) || 1;
    const existingValues = getExistingValues(depth);

    container.replaceChildren();
    for (let i = 1; i <= depth; i++) {
      createField(i, existingValues[i]).forEach(node => container.appendChild(node));
    }

    container.querySelectorAll('[data-bs-toggle="tooltip"]')
      .forEach(el => new bootstrap.Tooltip(el));
  };

  toggle.addEventListener("change", updateFields);
  depthField?.addEventListener("input", updateFields);
});
