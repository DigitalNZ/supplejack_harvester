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
  resolve: {
    alias: {
      '~bootstrap': path.resolve(__dirname, 'node_modules/bootstrap'),
      '~autoComplete': path.resolve(__dirname, 'node_modules/@tarekraafat/autocomplete.js'),
      '~bootstrap-icons': path.resolve(__dirname, 'node_modules/bootstrap-icons'),
      '~tom-select': path.resolve(__dirname, 'node_modules/tom-select'),
    }
  },
})
