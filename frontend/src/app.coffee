import {Component} from 'react'
import h from 'react-hyperscript'

import {BrowserRouter as Router, Route, Redirect, Switch, useContext} from 'react-router-dom'

import {APIContext} from './api'
import {AppMode, UserRole} from './enum'
import {LoginForm} from './login-form'
import {ResultsLandingPage} from './landing-page'
import {KnowledgeBaseFilterView} from './knowledge-base'
import {ResultsPage} from './results-page'
import {TaggingPage} from './tagging-page'
import {
  PermalinkProvider,
  PermalinkSwitch,
  PermalinkContext,
  permalinkRouteTemplate
} from './permalinks'

# /annotation/{stack_id}/page/{image_id}


MainRouter = ({appMode, basename, rest...})->
  h PermalinkProvider, {appMode}, (
    h 'div.app-main', null, (
      h Router, {basename}, (
        h(Switch, rest)
      )
    )
  )

class TaggingApplication extends Component
  @contextType: APIContext
  constructor: (props)->
    super props
    @state = {
      people: null
      person: null
    }

  allRequiredOptionsAreSet: (role)=>
    {person} = @state
    return false unless role?
    # Doesn't matter what privileges we have to view tags
    return true if role == UserRole.VIEW_TRAINING
    # We should have a person if another option is required
    return false unless person?
    if role == UserRole.TAG
      return person.tagger
    if role == UserRole.VALIDATE
      return person.validator
    return false

  renderUI: ({match, role})=>

    # Go to specific image by default, if set
    {params: {role: newRole, imageId, stackId}} = match
    {person} = @state
    # Allow role to be overridden by programmatically
    # set one (to support permalinks)
    role ?= newRole

    if not @allRequiredOptionsAreSet(role)
      return h Redirect, {to: '/'}

    imageRoute = "/image"

    id = null
    if person?
      id = person.person_id
    extraSaveData = null
    nextImageEndpoint = "/image/next"
    allowSaveWithoutChanges = false
    editingEnabled = true

    if role == UserRole.TAG and id?
      extraSaveData = {tagger: id}
      subtitleText = "Tag"
    if role == UserRole.VIEW_TRAINING
      editingEnabled = false
      nextImageEndpoint = "/image/validate"
      allowSaveWithoutChanges = false
      subtitleText = "View training data"
    else if role == UserRole.VALIDATE and id?
      extraSaveData = {validator: id}
      nextImageEndpoint = "/image/validate"
      # Tags can be validated even when unchanged
      allowSaveWithoutChanges = true
      subtitleText = "Validate"

    # This is a hack to disable "NEXT" for now
    # on permalinked images
    navigationEnabled
    if imageId?
      navigationEnabled = false

    console.log "Setting up UI with role #{role}"
    console.log "Image id: #{imageId}"

    return h TaggingPage, {
      imageRoute
      # This way of tracking stack ID is pretty dumb, potentia
      stack_id: stackId
      extraSaveData
      navigationEnabled
      nextImageEndpoint
      initialImage: imageId
      allowSaveWithoutChanges
      editingEnabled
      subtitleText
      @props...
    }

  renderLoginForm: =>
    {person, people} = @state
    return null unless people?
    h LoginForm, {
      person, people,
      setPerson: @setPerson
    }

  render: ->
    {publicURL} = @props
    h MainRouter, {
      basename: publicURL,
      appMode: AppMode.ANNOTATION
    }, [
      h Route, {
        path: '/',
        exact: true,
        render: @renderLoginForm
      }
      h Route, {
        # This should be included from the context, but
        # this is complicated from the react-router side
        path: permalinkRouteTemplate(AppMode.ANNOTATION)
        render: (props)=>
          role = UserRole.VIEW_TRAINING
          @renderUI({role, props...})
      }
      h Route, {path: '/action/:role', render: @renderUI}
    ]

  setupPeople: (d)=>
    @setState {people: d}

  setPerson: (person)=>
    @setState {person}
    localStorage.setItem('person', JSON.stringify(person))

  componentDidMount: =>
    @context.get("/people/all")
    .then @setupPeople

    p = localStorage.getItem('person')
    return unless p?
    @setState {person: JSON.parse(p)}

ViewerPage = ({match, rest...})=>
  # Go to specific image by default, if set
  {params: {imageId}} = match

  # This is a hack to disable "NEXT" for now
  # on permalinked images
  if imageId? and not rest.navigationEnabled?
    rest.navigationEnabled = false

  return h TaggingPage, {
    initialImage: imageId
    allowSaveWithoutChanges: false
    editingEnabled: false
    rest...
  }

ViewResults = ({match, rest...})=>
  # Go to specific image by default, if set
  {params: {imageId}} = match

  # This is a hack to disable "NEXT" for now
  # on permalinked images
  if imageId? and not rest.navigationEnabled?
    rest.navigationEnabled = false

  return h ResultsPage, {
    imageRoute: '/image'
    subtitleText: "View results"
    nextImageEndpoint: '/image/next_eqn_prediction'
    match...
  }

class App extends Component
  @contextType: APIContext
  @defaultProps: {
    appMode: AppMode.PREDICTION
  }
  render: ->
    {publicURL, appMode} = @props
    h MainRouter, {basename: publicURL, appMode}, [
      h Route, {
        path: '/',
        exact: true,
        component: ResultsLandingPage
      }
      h Route, {
        path: permalinkRouteTemplate(appMode)
        render: (props)=>
          h ViewerPage, {
            permalinkRoute: "/training/page"
            nextImageEndpoint: "/image/validate"
            subtitleText: "View training data"
            props...
          }
      }
      # This is probably deprecated
      h Route, {
        path: '/view-extractions/:imageId?',
        render: (props)=>
          h ViewerPage, {
            nextImageEndpoint: "/image/next_prediction"
            subtitleText: "View extractions"
            props...
          }
      }
      # h PermalinkRoute, {
      #   component: ViewResults
      # }
      h Route, {
        path: '/knowledge-base'
        component: KnowledgeBaseFilterView
      }
    ]

export {App, TaggingApplication}
