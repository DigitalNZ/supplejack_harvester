import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import FullReload from 'vite-plugin-full-reload'

const path = require('path')

export default defineConfig({
  plugins: [
    RubyPlugin(),
    FullReload(['config/routes.rb', 'app/views/**/*'], { delay: 200 })
  ],
  root: path.resolve(__dirname, 'src'),
  css: {
    preprocessorOptions: {
      // Bootstrap 5.3.8 predates the Sass deprecations it trips (@import, the global
      // built-ins, the colour functions) and emits some 350 warnings we cannot act on,
      // which buried the five that are ours. quietDeps silences the ones raised inside
      // node_modules only, so a deprecation we introduce is still heard.
      scss: { quietDeps: true }
    }
  },
  resolve: {
    alias: {
      '~bootstrap': path.resolve(__dirname, 'node_modules/bootstrap'),
      '~autoComplete': path.resolve(__dirname, 'node_modules/@tarekraafat/autocomplete.js'),
      '~bootstrap-icons': path.resolve(__dirname, 'node_modules/bootstrap-icons'),
      '~tom-select': path.resolve(__dirname, 'node_modules/tom-select'),
    }
  },
})
