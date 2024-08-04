import { some, filter } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

import { addFieldValue, deleteFieldValue } from '~/js/features/SchemaApp/FieldValuesSlice';

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

const fieldsAdapter = createEntityAdapter();

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
      })
      .addCase(addFieldValue.fulfilled, (state, action) => {
        state.entities[action.payload.schema_field_id].schema_field_value_ids.push(action.payload.id)
      })
      .addCase(deleteFieldValue.fulfilled, (state, action) => {
        const ids = filter(state.entities[action.meta.arg.schemaFieldId].schema_field_value_ids, (fieldId) => {
          return fieldId != action.payload;
        });

        state.entities[action.meta.arg.schemaFieldId].schema_field_value_ids = ids;
      })
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
