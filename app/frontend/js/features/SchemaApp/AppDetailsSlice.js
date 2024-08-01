import { createSlice } from "@reduxjs/toolkit";

const AppDetailsSlice = createSlice({
  name: "appDetails",
  initialState: {},
  reducers: {},
});

export const selectAppDetails = (state) => state.entities.appDetails;

const { reducer } = AppDetailsSlice;

export default reducer;
