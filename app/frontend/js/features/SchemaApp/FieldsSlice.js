import { some } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

export const addField = createAsyncThunk(
  "fields/addFieldStatus",
  async (payload) => {
    const {
      name,
      schemaId,
    } = payload;

    const response = request
      .post(
        `/schemas/${schemaId}/schema_fields`,
        {
          schema_field: {
            name: name,
            schema_id: schemaId
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const deleteField = createAsyncThunk(
  "fields/deleteFieldStatus",
  async (payload) => {
    const { id, schemaId } =
      payload;

    const response = request
      .delete(
        `/schemas/${schemaId}/schema_fields/${id}`
      )
      .then((response) => {
        return id;
      });

    return response;
  }
);

export const updateField = createAsyncThunk(
  "fields/updateFieldStatus",
  async (payload) => {
    const {
      id,
      schemaId,
      name,
      kind,
    } = payload;

    const response = request
      .patch(
        `/schemas/${schemaId}/schema_fields/${id}`,
        {
          schema_field: {
            name: name,
            kind: kind,
          },
        }
      )
      .then((response) => {
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
      .addCase(addField.fulfilled, (state, action) => {
        fieldsAdapter.upsertOne(state, action.payload);
      })
      .addCase(deleteField.fulfilled, (state, action) => {
        fieldsAdapter.removeOne(state, action.payload);
      })
      .addCase(updateField.fulfilled, (state, action) => {
        fieldsAdapter.setOne(state, action.payload);
      });
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
