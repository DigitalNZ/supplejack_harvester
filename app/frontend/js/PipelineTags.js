// The tag editor on the pipeline page. The chips carry the hidden inputs the form
// submits, so adding and removing tags is a matter of adding and removing chips - what
// is on the pipeline when Save is pressed is whatever is in the box at that moment.
const root = document.querySelector("[data-pipeline-tags]");

if (root) {
  const editButton = root.querySelector("[data-tags-edit]");
  const editor = root.querySelector("[data-tags-editor]");
  const chipList = root.querySelector("[data-tags-chips]");
  const emptyNotice = root.querySelector("[data-tags-empty]");
  const input = root.querySelector("[data-tags-input]");
  const suggestionList = root.querySelector("[data-tags-suggestions]");
  const cancelButton = root.querySelector("[data-tags-cancel]");
  const chipTemplate = root.querySelector("[data-tag-chip-template]");

  const knownNames = JSON.parse(root.dataset.tags || "[]");

  const chipNames = () =>
    [...chipList.querySelectorAll("[data-tag-chip]")].map(
      (chip) => chip.dataset.tagName
    );

  // What the pipeline is saved with, so Cancel can put the box back.
  const savedNames = chipNames();

  const sameName = (one, other) => one.toLowerCase() === other.toLowerCase();

  const isChipped = (name) =>
    chipNames().some((chipped) => sameName(chipped, name));

  function syncEmptyNotice() {
    emptyNotice.classList.toggle("d-none", chipNames().length > 0);
  }

  function addChip(name) {
    // An existing tag keeps its own spelling however the name was typed.
    const tagName = knownNames.find((known) => sameName(known, name)) || name;

    const chip = chipTemplate.content.firstElementChild.cloneNode(true);
    chip.dataset.tagName = tagName;
    chip.querySelector("[data-tag-chip-name]").textContent = tagName;
    chip.querySelector("[data-tag-chip-value]").value = tagName;
    chip
      .querySelector("[data-tag-remove]")
      .setAttribute("aria-label", `Remove ${tagName}`);

    chipList.appendChild(chip);
    syncEmptyNotice();
  }

  function hideSuggestions() {
    suggestionList.classList.remove("show");
  }

  // Adding a tag closes the list: it sits over the Save and Cancel buttons, and typing
  // again is what asks for suggestions back.
  function addTag(name) {
    const trimmed = name.trim();
    if (trimmed && !isChipped(trimmed)) addChip(trimmed);

    input.value = "";
    hideSuggestions();
  }

  function suggestionButton(label, name, extraClass = "") {
    const item = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.className = `dropdown-item ${extraClass}`.trim();
    button.textContent = label;
    button.addEventListener("mousedown", (event) => {
      // The input's blur would close the list before a click landed on it.
      event.preventDefault();
      addTag(name);
      input.focus();
    });
    item.appendChild(button);
    return item;
  }

  function renderSuggestions() {
    const query = input.value.trim();
    suggestionList.replaceChildren();

    const matches = knownNames.filter(
      (name) =>
        !isChipped(name) &&
        (!query || name.toLowerCase().includes(query.toLowerCase()))
    );
    matches.forEach((name) =>
      suggestionList.appendChild(suggestionButton(name, name))
    );

    const isNewName =
      query &&
      !knownNames.some((known) => sameName(known, query)) &&
      !isChipped(query);
    if (isNewName) {
      suggestionList.appendChild(
        suggestionButton(
          `+ Create tag "${query}"`,
          query,
          "text-success fw-semibold"
        )
      );
    }

    suggestionList.classList.toggle(
      "show",
      suggestionList.childElementCount > 0
    );
  }

  function openEditor() {
    editButton.classList.add("d-none");
    editor.classList.remove("d-none");
    renderSuggestions();
    input.focus();
  }

  function closeEditor() {
    editor.classList.add("d-none");
    editButton.classList.remove("d-none");
    hideSuggestions();
  }

  function cancelEditing() {
    chipList.replaceChildren();
    savedNames.forEach(addChip);
    input.value = "";
    closeEditor();
  }

  editButton.addEventListener("click", openEditor);
  cancelButton.addEventListener("click", cancelEditing);
  input.addEventListener("input", renderSuggestions);
  input.addEventListener("focus", renderSuggestions);

  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      // Enter belongs to the tag being typed, not to the form.
      event.preventDefault();
      addTag(input.value);
    } else if (event.key === "Escape") {
      cancelEditing();
    }
  });

  chipList.addEventListener("click", (event) => {
    const remove = event.target.closest("[data-tag-remove]");
    if (!remove) return;

    remove.closest("[data-tag-chip]").remove();
    syncEmptyNotice();
  });

  // The list sits over the Save and Cancel buttons, so it closes as soon as the input is
  // done with. Suggestions are added on mousedown, which runs before this blur.
  input.addEventListener("blur", hideSuggestions);
}
