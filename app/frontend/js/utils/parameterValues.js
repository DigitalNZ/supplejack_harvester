// A parameter's content is stored as text; its value_type says how the request layer
// reads it (see Parameter#typed_content). The payload preview reads it the same way so
// what the editor shows is what the content source is sent.

export function typedParameterValue({ content, value_type }) {
  if (content === "" || content === null || content === undefined) {
    return content;
  }

  switch (value_type) {
    case "integer": {
      const number = Number(content);
      return Number.isInteger(number) ? number : content;
    }
    case "boolean":
      return content === "true";
    case "json":
      try {
        return JSON.parse(content);
      } catch {
        return content;
      }
    default:
      return content;
  }
}
