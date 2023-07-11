import { createAsyncThunk, createSlice } from "@reduxjs/toolkit";
import { request } from "../utils/request";

export const askNewRawRecord = createAsyncThunk(
  "fields/askNewRawRecordStatus",
  async (payload) => {
    const { transformationDefinitionId, page, record } = payload;

    const response = request
      .get(
        `/transformation_definitions/${transformationDefinitionId}/raw_records`,
        { params: { page: page, record: record } }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

const rawRecordSlice = createSlice({
  name: "rawRecordSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(askNewRawRecord.pending, (state) => {
        state.isFetching = true;
      })
      .addCase(askNewRawRecord.fulfilled, (state, action) => {
        state.isFetching = false;
        state.page = action.payload.page;
        state.record = action.payload.record;
        state.body = action.payload.body;

        window.history.replaceState(
          null,
          null,
          `${window.location.pathname}?page=${state.page}&record=${state.record}`
        );
      });
  },
});

const { actions, reducer } = rawRecordSlice;

export const selectRawRecord = (state) => state.entities.rawRecord;

export const {} = actions;

export default reducer;
