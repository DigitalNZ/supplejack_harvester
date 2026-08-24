import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

import { some } from "lodash";

// A parameter the model refused comes back as 422 with its messages. Anything else -
// a 500, a dropped connection - has no message worth showing a field, so it is named
// as what it is.
function validationErrors(error) {
  return (
    error.response?.data?.errors || [
      "Could not be saved, please try again or check the logs",
    ]
  );
}

const parametersAdapter = createEntityAdapter({
  sortComparer: (parameterOne, parameterTwo) =>
    parameterTwo.created_at.localeCompare(parameterOne.created_at),
});

export const addParameter = createAsyncThunk(
  "parameters/addParameterStatus",
  async (payload, { rejectWithValue }) => {
    const {
      name,
      content,
      kind,
      content_type,
      value_type,
      harvestDefinitionId,
      pipelineId,
      extractionDefinitionId,
      requestId,
    } = payload;

    try {
      const response = await request.post(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/extraction_definitions/${extractionDefinitionId}/requests/${requestId}/parameters`,
        {
          parameter: {
            request_id: requestId,
            kind: kind,
            name: name,
            content: content,
            content_type: content_type,
            value_type: value_type,
          },
        }
      );

      return response.data;
    } catch (error) {
      return rejectWithValue(validationErrors(error));
    }
  }
);

export const updateParameter = createAsyncThunk(
  "parameters/updateParameterSlice",

  async (payload, { rejectWithValue }) => {
    const {
      id,
      pipelineId,
      harvestDefinitionId,
      extractionDefinitionId,
      requestId,
      name,
      content,
      kind,
      content_type,
      value_type,
    } = payload;

    try {
      const response = await request.patch(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/extraction_definitions/${extractionDefinitionId}/requests/${requestId}/parameters/${id}`,
        {
          parameter: {
            name: name,
            content: content,
            kind: kind,
            content_type: content_type,
            value_type: value_type,
          },
        }
      );

      return response.data;
    } catch (error) {
      return rejectWithValue(validationErrors(error));
    }
  }
);

export const deleteParameter = createAsyncThunk(
  "parameters/deleteParameterStatus",
  async (payload) => {
    const {
      id,
      pipelineId,
      harvestDefinitionId,
      extractionDefinitionId,
      requestId,
    } = payload;

    const response = request
      .delete(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/extraction_definitions/${extractionDefinitionId}/requests/${requestId}/parameters/${id}`
      )
      .then((response) => {
        return id;
      });

    return response;
  }
);

const parametersSlice = createSlice({
  name: "parametersSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addParameter.fulfilled, (state, action) => {
        parametersAdapter.upsertOne(state, action.payload);
      })
      .addCase(deleteParameter.fulfilled, (state, action) => {
        parametersAdapter.removeOne(state, action.payload);
      })
      .addCase(updateParameter.fulfilled, (state, action) => {
        parametersAdapter.setOne(state, action.payload);
      });
  },
});

const { actions, reducer } = parametersSlice;

export const {
  selectById: selectParameterById,
  selectIds: selectParameterIds,
  selectAll: selectAllParameters,
} = parametersAdapter.getSelectors((state) => state.entities.parameters);

export const hasEmptyParameters = (state) => {
  return some(selectAllParameters(state), { content: "" });
};

export const selectParameterIdsByRequestAndKind = (state, requestId, type) => {
  return selectAllParameters(state)
    .filter((parameter) => parameter.request_id === requestId)
    .filter((parameter) => parameter.kind === type)
    .map((parameter) => parameter.id);
};

export const {} = actions;

export default reducer;
