import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

export const addFieldSchemaFieldValue = createAsyncThunk(
  "fields/addFieldSchemaFieldValueStatus",
  async (payload) => {
    const {
      fieldId,
      schemaFieldValueId
    } = payload;

    const response = request
      .post(
        `/field_schema_field_values`,
        {
          field_schema_field_value: {
            field_id: fieldId,
            schema_field_value_id: schemaFieldValueId
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const updateFieldSchemaFieldValue = createAsyncThunk(
  "fields/updateFieldSchemaFieldValueStatus",
  async (payload) => {
    const {
      id,
      schemaFieldValueId
    } = payload;

    const response = request
      .patch(
        `/field_schema_field_values/${id}`,
        {
          field_schema_field_value: {
            schema_field_value_id: schemaFieldValueId
          },
        }
      )
      .then((response) => {
        return response.data;
      });

    return response;
  }
);

const fieldSchemaFieldValuesAdapter = createEntityAdapter();

const fieldSchemaFieldValuesSlice = createSlice({
  name: "fieldSchemaFieldValuesSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addFieldSchemaFieldValue.fulfilled, (state, action) => {
        fieldSchemaFieldValuesAdapter.upsertOne(state, action.payload);
      })
      .addCase(updateFieldSchemaFieldValue.fulfilled, (state, action) => {
        fieldSchemaFieldValuesAdapter.setOne(state, action.payload);
      });
  },
});

const { actions, reducer } = fieldSchemaFieldValuesSlice;

export const {
  selectById: selectFieldSchemaFieldValueById,
  selectIds: selectFieldSchemaFieldValueIds,
  selectAll: selectAllFieldsSchemaFieldValues,
} = fieldSchemaFieldValuesAdapter.getSelectors((state) => state.entities.fieldSchemaFieldValues);

export const { } = actions;

export default reducer;
