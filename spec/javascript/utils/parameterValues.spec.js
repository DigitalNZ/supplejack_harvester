import { typedParameterValue } from "~/js/utils/parameterValues";

describe("typedParameterValue", () => {
  it("reads content as a string by default", () => {
    expect(
      typedParameterValue({ content: "deleted", value_type: "string" })
    ).toEqual("deleted");
  });

  it("reads JSON content as the structure it describes", () => {
    expect(
      typedParameterValue({
        content: '{"status": "deleted"}',
        value_type: "json",
      })
    ).toEqual({ status: "deleted" });
  });

  it("reads integer content as a number", () => {
    expect(typedParameterValue({ content: "30", value_type: "integer" })).toEqual(
      30
    );
  });

  it("reads boolean content as a boolean", () => {
    expect(
      typedParameterValue({ content: "false", value_type: "boolean" })
    ).toEqual(false);
  });

  // The editor saves the type on its own, so it can be looking at content the model
  // has not accepted yet - it shows what is there rather than nothing.
  it("falls back to the content when it does not parse", () => {
    expect(
      typedParameterValue({ content: "{status: deleted}", value_type: "json" })
    ).toEqual("{status: deleted}");
  });

  it("leaves blank content alone", () => {
    expect(typedParameterValue({ content: "", value_type: "json" })).toEqual("");
  });
});
