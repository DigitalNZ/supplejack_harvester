import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

import { updateExtractionDefinition } from "~/js/features/ExtractionApp/AppDetailsSlice";

const requestsAdapter = createEntityAdapter();

export const previewRequest = createAsyncThunk(
  "requests/previewRequestSlice",

  async (payload) => {
    const {
      id,
      pipelineId,
      harvestDefinitionId,
      extractionDefinitionId,
      previousRequestId,
      pipelineJobId,
      page,
      record,
    } = payload;

    let path = `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/extraction_definitions/${extractionDefinitionId}/requests/${id}?page=${page}&record=${record}`;

    if (previousRequestId != undefined) {
      path = `${path}&previous_request_id=${previousRequestId}`;
    }

    if (pipelineJobId != undefined && pipelineJobId != null) {
      path = `${path}&pipeline_job_id=${pipelineJobId}`;
    }

    const response = request.get(path).then((response) => {
      return response.data;
    });

    return response;
  }
);

export const updateRequest = createAsyncThunk(
  "requests/updateRequestSlice",

  async (payload) => {
    const {
      id,
      pipelineId,
      harvestDefinitionId,
      extractionDefinitionId,
      http_method,
    } = payload;

    const response = request
      .patch(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/extraction_definitions/${extractionDefinitionId}/requests/${id}`,
        {
          request: {
            http_method: http_method,
          },
        }
      )
      .then((response) => {
        return response.data;
      });

    return response;
  }
);

const requestsSlice = createSlice({
  name: "requestsSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(updateRequest.fulfilled, (state, action) => {
        requestsAdapter.setOne(state, action.payload);
      })
      .addCase(previewRequest.fulfilled, (state, action) => {
        requestsAdapter.setOne(state, action.payload);
      })
      .addCase(updateExtractionDefinition.fulfilled, (state, action) => {
        const { base_url, format } = action.payload;

        requestsAdapter.updateMany(
          state,
          state.ids.map((id) => {
            return {
              id: id,
              changes: { base_url: base_url, format: format, url: base_url },
            };
          })
        );
      });
  },
});

const { actions, reducer } = requestsSlice;

export const {
  selectById: selectRequestById,
  selectIds: selectRequestIds,
  selectAll: selectAllRequests,
} = requestsAdapter.getSelectors((state) => state.entities.requests);

export const {} = actions;

export default reducer;
