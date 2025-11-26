import { createAsyncThunk, createSlice } from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

export const updateExtractionDefinition = createAsyncThunk(
  "fields/updateExtractionDefinitionStatus",
  async (payload) => {
    const {
      id,
      pipeline_id,
      harvest_definition_id,
      base_url,
      total_selector,
      per_page,
      throttle,
      paginated,
      format,
    } = payload;

    const response = request
      .patch(
        `/pipelines/${pipeline_id}/harvest_definitions/${harvest_definition_id}/extraction_definitions/${id}`,
        {
          extraction_definition: {
            format: format,
            base_url: base_url,
            total_selector: total_selector,
            per_page: per_page,
            throttle: throttle,
            paginated: paginated,
          },
        }
      )
      .then((response) => {
        return response.data;
      });

    return response;
  }
);

const AppDetailsSlice = createSlice({
  name: "appDetails",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder.addCase(updateExtractionDefinition.fulfilled, (state, action) => {
      state.extractionDefinition = action.payload;
    });
  },
});

export const selectAppDetails = (state) => state.entities.appDetails;
export const selectHarvestDefinition = (state) =>
  state.entities.appDetails.harvestDefinition;

const { actions, reducer } = AppDetailsSlice;

export default reducer;
