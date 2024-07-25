import { createSlice, createEntityAdapter } from "@reduxjs/toolkit";

const uiFieldsAdapter = createEntityAdapter();

const uiFieldsSlice = createSlice({
  name: "fieldsSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
  },
});

const { actions, reducer } = uiFieldsSlice;

export const {
  selectById: selectUiFieldById,
  selectIds: selectUiFieldIds,
  selectAll: selectAllUiFields,
} = uiFieldsAdapter.getSelectors((state) => state.ui.fields);

export const selectDisplayedFieldIds = (state) => {
  return selectAllUiFields(state)
    .filter((field) => field.displayed)
    .map((field) => field.id);
};

export const { toggleDisplayField, toggleDisplayFields, setActiveField } =
  actions;

export default reducer;
