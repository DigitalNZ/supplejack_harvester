import { some } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";

export const addField = createAsyncThunk(
  "fields/addFieldStatus",
  async (payload) => {
    console.log(payload);
    const {
      name,
      schemaId,
    } = payload;

    const response = request
      .post(
        `/schemas/${schemaId}/fields`,
        {
          field: {
            name: name,
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const hasEmptyFields = (state) => {
  return some(selectAllFields(state), { name: "" });
};

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
