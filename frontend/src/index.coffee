import '@macrostrat/ui-components/ui-init'
import "@blueprintjs/select/lib/css/blueprint-select.css"
import './main.styl'

import {render} from 'react-dom'
import h from 'react-hyperscript'
import {App, TaggingApplication} from './app'
import {APIProvider} from './api'
import {ImageStoreProvider} from './image-container'

console.log("Application running in mode:")
console.log(process.env.APPMODE)
if process.env.APPMODE == 'ANNOTATION'
  AppHolder = (props)=>
    {baseURL, imageBaseURL, publicURL, rest...} = props
    h APIProvider, {baseURL}, [
      h ImageStoreProvider, {baseURL: imageBaseURL, publicURL}, [
          h TaggingApplication, {imageBaseURL, publicURL, rest...}
      ]
    ]
else if process.env.APPMODE == 'PREDICTION'
  AppHolder = (props)=>
    {baseURL, imageBaseURL, publicURL, rest...} = props
    h APIProvider, {baseURL}, [
      h ImageStoreProvider, {baseURL: imageBaseURL, publicURL}, [
          h App, {imageBaseURL, publicURL, rest...}
      ]
    ]

window.createUI = (opts={})->
  {baseURL, imageBaseURL, publicURL} = opts

  try
    # Attempt to set parameters from environment variables
    # This will fail if bundled on a different system, presumably,
    # so we wrap in try/catch.
    publicURL = process.env.PUBLIC_URL
    baseURL = process.env.API_BASE_URL
    imageBaseURL = process.env.IMAGE_BASE_URL
  catch error
    console.log error

  console.log """
  Environment variables:
  PUBLIC_URL: #{process.env.PUBLIC_URL}
  API_BASE_URL: #{process.env.API_BASE_URL}
  IMAGE_BASE_URL: #{process.env.IMAGE_BASE_URL}
  """

  # Set reasonable defaults
  publicURL ?= "/"
  baseURL ?= "https://dev.macrostrat.org/image-tagger-api"
  imageBaseURL ?= "https://dev.macrostrat.org/image-tagger/img/"

  console.log publicURL, baseURL, imageBaseURL

  # Image base url is properly set here
  el = document.createElement('div')
  document.body.appendChild(el)
  __ = h AppHolder, {baseURL, imageBaseURL, publicURL}
  render __, el

# Actually run the UI (changed for webpack)
window.createUI()
