// A description shows one of three states at a time: a clamped preview, the whole thing in a card,
// and the edit form. The pipeline, the automation template and the definitions all draw the same
// editor, so this drives every one on the page rather than only the first.
document.querySelectorAll(".js-description").forEach((description) => {
  const collapsed = description.querySelector(".js-description-collapsed");
  const expanded = description.querySelector(".js-description-expanded");
  const form = description.querySelector(".js-description-form");
  const clamp = description.querySelector(".js-description-clamp");
  const more = description.querySelector(".js-description-more");

  const show = (state) => {
    [collapsed, expanded, form].forEach((element) => {
      element.classList.toggle("d-none", element !== state);
    });
  };

  // Only the browser knows whether 5 lines were enough to hold the description, so the offer to
  // read the rest of it waits until the clamp has cut something off.
  if (clamp && clamp.scrollHeight > clamp.clientHeight) {
    more.classList.remove("d-none");
  }

  description.querySelectorAll(".js-description-edit").forEach((control) => {
    control.addEventListener("click", () => show(form));
  });

  description
    .querySelector(".js-description-expand")
    .addEventListener("click", (event) => {
      event.preventDefault();

      show(expanded);
    });

  description
    .querySelector(".js-description-collapse")
    .addEventListener("click", (event) => {
      event.preventDefault();

      show(collapsed);
    });

  description
    .querySelector(".js-description-cancel")
    .addEventListener("click", () => {
      form.querySelector("form").reset();

      show(collapsed);
    });
});
