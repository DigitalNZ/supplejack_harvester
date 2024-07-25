
import {
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";

const fieldsAdapter = createEntityAdapter({
  sortComparer: (fieldOne, fieldTwo) =>
    fieldTwo.created_at.localeCompare(fieldOne.created_at),
});

const fieldsSlice = createSlice({
  name: "fieldsSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
  },
});

const { actions, reducer } = fieldsSlice;

export const {
  selectById: selectFieldById,
  selectIds: selectFieldIds,
  selectAll: selectAllFields,
} = fieldsAdapter.getSelectors((state) => state.entities.fields);

export const { } = actions;

export default reducer;
