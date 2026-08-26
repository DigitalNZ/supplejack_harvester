import React from 'react'
import { render } from '@testing-library/react'
import { Provider } from 'react-redux'

import configureAppStore from '~/js/apps/TransformationApp/store'

export function renderWithProviders(
  ui,
  { preloadedState, store = configureAppStore(preloadedState), ...renderOptions } = {}
) {
  function Wrapper({ children }) {
    return <Provider store={store}>{children}</Provider>
  }

  // Return an object with the store and all of RTL's query functions
  return { store, ...render(ui, { wrapper: Wrapper, ...renderOptions }) }
}
