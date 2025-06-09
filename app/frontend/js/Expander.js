import { each } from "lodash";

const expanders = document.getElementsByClassName("expander");

each(expanders, (expander) => {
  expander.addEventListener("click", (_event) => {
    expander.classList.toggle("expander--active");
  });
});
