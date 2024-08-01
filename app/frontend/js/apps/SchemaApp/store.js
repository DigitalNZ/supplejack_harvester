import { combineReducers, configureStore } from "@reduxjs/toolkit";

// entities

import fields from '/js/features/SchemaApp/FieldsSlice';
import appDetails from '/js/features/SchemaApp/AppDetailsSlice';

// ui

import uiFields from '/js/features/SchemaApp/UiFieldsSlice';

// config
import config from "/js/features/ConfigSlice";

export default function configureAppStore(preloadedState) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({
        fields,
        appDetails
      }),
      ui: combineReducers({
        fields: uiFields
      }),
      config,
    }),
    preloadedState
  });

  return store;
}
