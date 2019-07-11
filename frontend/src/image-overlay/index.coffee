import {Component, createContext} from 'react'
import h from 'react-hyperscript'
import {select, event} from 'd3-selection'
import {drag} from 'd3-drag'
import {findDOMNode} from 'react-dom'
import {Hotkey, Hotkeys,
        HotkeysTarget, Intent} from "@blueprintjs/core"
import {StatefulComponent} from '@macrostrat/ui-components'

import {Tag, LockedTag} from '../annotation'
import {AnnotationLinks} from './annotation-links'
import {TypeSelector} from './type-selector'
import {EditorContext} from './context'

import chroma from 'chroma-js'
import {EditMode} from '../enum'
import {Card, Button} from '@blueprintjs/core'
import classNames from 'classnames'

import './main.styl'

{ADD_PART, LINK} = EditMode
SHIFT_MODES = new Set([LINK, ADD_PART])

class ModalNotifications extends Component
  @contextType: EditorContext
  Messages: {
    [ADD_PART]: "Add part"
    [LINK]: "Add link"
  }
  renderToast: (mode)->
    {actions, editModes, shiftKey} = @context
    return null unless editModes.has(mode)
    message = @Messages[mode]
    onClick = (event)=>
      event.stopPropagation()
      actions.setMode(mode, false)

    deleteButton = null
    if not shiftKey
      deleteButton = h Button, {
        minimal: true,
        icon: 'cross',
        intent: Intent.DANGER,
        onClick
      }

    className = classNames("edit-mode", mode)
    h Card, {className, icon: null}, [
      h 'span.mode', "Mode"
      h 'span.message', message
      deleteButton
    ]

  render: ->
    h 'div.notifications', [
      @renderToast(ADD_PART)
      @renderToast(LINK)
    ]

class ImageOverlay extends StatefulComponent
  @defaultProps: {
    # Distance we take as a click before switching to drag
    clickDistance: 10
    editingEnabled: true
    selectIsOpen: false
    lockedTags: new Set([])
  }
  constructor: (props)->
    super props
    @state = {
      inProgressAnnotation: null
      editModes: new Set()
      shiftKey: false
      clickingInRect: null
    }

  componentWillReceiveProps: (nextProps)=>
    return if nextProps.editingRect == @props.editingRect
    return if nextProps.editingRect?
    @updateState {editModes: {$set: new Set()}}

  selectAnnotation: (ix)=>(event)=>
    {actions, editModes} = @contextValue()
    # Make sure we don't activate the
    # general click or drag handlers
    if editModes.has(LINK)
      do actions.addLink(ix)
      actions.setMode(LINK, false)
    else
      do actions.selectAnnotation(ix)

  renderAnnotations: ->
    {inProgressAnnotation} = @state
    {image_tags, tags, width, height, lockedTags
      editingRect, actions, scaleFactor} = @props

    if inProgressAnnotation?
      editingRect = null
      image_tags = [image_tags..., inProgressAnnotation]

    console.log image_tags
    image_tags.map (d, ix)=>
      locked = lockedTags.has(d.tag_id)
      if locked
        return h LockedTag, {tags, d...}

      _editing = ix == editingRect and not locked

      opacity = if _editing then 0.5 else 0.3

      opts = {
        key: ix
        d...
        tags
        scaleFactor
        maxPosition: {width, height}
        locked
      }

      if _editing
        opts = {
          delete: actions.deleteAnnotation(ix)
          update: actions.updateAnnotation(ix)
          onSelect: @toggleSelect
          enterLinkMode: ->
          opts...
        }
      onMouseDown = =>
        #return if editingRect == ix
        do @selectAnnotation(ix)
        @setState {clickingInRect: ix}
        # Don't allow dragging
        event.stopPropagation()

      return h Tag, {
        onMouseDown, opts...
      }

  renderInterior: ->
    {editingRect, width, height, image_tags,
     scaleFactor, tags, currentTag, lockedTags, actions,
     rest...} = @props
    size = {width, height}
    {selectIsOpen} = @state

    onClick = @disableEditing

    h 'div', [
      h TypeSelector, {
        tags
        lockedTags
        currentTag
        toggleLock: actions.toggleTagLock or ->
        isOpen: selectIsOpen
        onClose: => @setState {selectIsOpen: false}
        onItemSelect: @selectTag
      }
      h 'div.overlay', {style: size, onClick}, @renderAnnotations()
      h AnnotationLinks, {image_tags, scaleFactor, tags, size...}
      h ModalNotifications
    ]

  tagColor: (tag_id)=>
    {tags} = @props
    tagData = tags.find (d)->d.tag_id == tag_id
    tagData ?= {color: 'black'}
    chroma(tagData.color)

  contextValue: =>
    {actions, tags, currentTag, scaleFactor, width, height} = @props
    {editModes, shiftKey} = @state
    if shiftKey then editModes = SHIFT_MODES
    actions.setMode = @setMode
    helpers = {tagColor: @tagColor}

    return {
      tags
      currentTag
      scaleFactor
      imageSize: {width, height}
      editModes
      shiftKey
      actions
      helpers
      update: @updateState
    }

  setMode: (mode, val)=>
    val ?= not @state.editModes.has(mode)
    action = if val then "$add" else "$remove"
    @updateState {editModes: {[action]: [mode]}}

  render: ->
    h EditorContext.Provider, {value: @contextValue()}, @renderInterior()

  selectTag: (tag)=>
    # Selects the Tag ID for active annotation
    {actions, editingRect} = @props
    if editingRect?
      # Set tag for the active rectangle
      fn = actions.updateAnnotation(editingRect)
      fn {tag_id: {$set: tag.tag_id}}
    else
      do actions.updateCurrentTag(tag.tag_id)
    @setState {selectIsOpen: false}

  handleDrag: =>
    {subject} = event
    {x,y} = subject
    {clickDistance, editingRect, currentTag,
     scaleFactor, editingEnabled,
     lockedTags, image_tags} = @props
    {clickingInRect} = @state
    return if not editingEnabled
    if lockedTags.has(currentTag)
      throw "Attempting to create a locked tag"

    # Make sure we color with the tag this will be
    {editModes} = @contextValue()
    if editModes.has(ADD_PART) and editingRect?
      currentTag = image_tags[editingRect].tag_id

    scaleFactor ?= 1
    width = event.x-x
    height = event.y-y
    if width < 0
      width *= -1
      x -= width
    if height < 0
      height *= -1
      y -= height
    return if width < clickDistance
    return if height < clickDistance
    # Shift to image coordinates from pixel coordinates
    x *= scaleFactor
    y *= scaleFactor
    width *= scaleFactor
    height *= scaleFactor

    # We are adding a new annotation
    boxes = [[x,y,x+width,y+height]]
    rect = {boxes, tag_id: currentTag}
    @setState {inProgressAnnotation: rect, clickingInRect: null}

  handleAddAnnotation: =>
    {actions, editingRect} = @props
    {inProgressAnnotation: r} = @state
    @setState {inProgressAnnotation: null}

    return unless r?
    {editModes} = @contextValue()
    if editModes.has(ADD_PART) and editingRect?
      # We are adding a box to the currently
      # selected annotation
      fn = actions.updateAnnotation(editingRect)
      fn {boxes: {$push: r.boxes}}
      # Disable linking mode
    else
      actions.appendAnnotation r
    @setMode(ADD_PART, false)

  disableEditing: =>
    {actions,editingRect} = @props
    return unless editingRect?
    __ = {editingRect: {$set: null}}
    actions.updateState __

  toggleSelect: =>
    console.log "Opening select box"
    @setState {selectIsOpen: true}

  renderHotkeys: ->
    {editingRect, actions} = @props
    h Hotkeys, null, [
      h Hotkey, {
        label: "Delete rectangle"
        combo: "backspace"
        global: true
        preventDefault: true
        onKeyDown: (evt)=>
          return unless editingRect?
          actions.deleteAnnotation(editingRect)()
      }
      h Hotkey, {
        global: true
        combo: "l"
        label: "Toggle select"
        onKeyDown: @toggleSelect
        #prevent typing "O" in omnibar input
        preventDefault: true
      }
      h Hotkey, {
        label: "Expose secondary commands"
        combo: "shift"
        global: true
        onKeyDown: @handleShift(true)
      }
    ]

  handleShift: (val)=> =>
    @setState {shiftKey: val}

  componentDidMount: ->
    el = select findDOMNode @

    # Set up dragging when rectangle is not clicked
    @edgeDrag = drag()
      .on "drag", @handleDrag
      .on "end", @handleAddAnnotation
      .clickDistance @props.clickDistance

    el.call @edgeDrag

    select(document).on 'keyup', (d)=>
      if @state.shiftKey and not event.shiftKey
        do @handleShift(false)

ImageOverlay = HotkeysTarget(ImageOverlay)

export {ImageOverlay}
