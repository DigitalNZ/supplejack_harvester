import { combineReducers, configureStore } from "@reduxjs/toolkit";

// entities

import fields from '/js/features/SchemaApp/FieldsSlice';

// ui

import uiFields from '/js/features/SchemaApp/UiFieldsSlice';

// config
import config from "/js/features/ConfigSlice";

export default function configureAppStore(preloadedState) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({
        fields
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
