import { combineReducers, configureStore } from "@reduxjs/toolkit";

// entities

import schemaFields from '/js/features/SchemaApp/SchemaFieldsSlice';
import fieldValues from '/js/features/SchemaApp/FieldValuesSlice';
import appDetails from '/js/features/SchemaApp/AppDetailsSlice';

// ui

import uiSchemaFields from '/js/features/SchemaApp/UiSchemaFieldsSlice';

// config
import config from "/js/features/ConfigSlice";

export default function configureAppStore(preloadedState) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({
        schemaFields,
        fieldValues,
        appDetails
      }),
      ui: combineReducers({
        schemaFields: uiSchemaFields
      }),
      config,
    }),
    preloadedState
  });

  return store;
}
