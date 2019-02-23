import {Component} from 'react'
import h from 'react-hyperscript'
import {select, event} from 'd3-selection'
import {drag} from 'd3-drag'
import {findDOMNode} from 'react-dom'
import {Hotkey, Hotkeys, HotkeysTarget} from "@blueprintjs/core"
import {Tag, ActiveTag, tagColor} from '../annotation'
import {AnnotationLinks} from './annotation-links'
import {TypeSelector} from './type-selector'

import './main.styl'

class Overlay extends Component
  @defaultProps: {
    # Distance we take as a click before switching to drag
    clickDistance: 10
    editingEnabled: true
    selectIsOpen: false
  }
  constructor: (props)->
    super props
    @state = {
      inProgressAnnotation: null
    }

  renderAnnotations: ->
    {inProgressAnnotation} = @state
    {image_tags, tags, width, height,
     editingRect, actions, scaleFactor} = @props

    if inProgressAnnotation?
      editingRect = null
      image_tags = [image_tags..., inProgressAnnotation]

    image_tags.map (d, ix)=>
      _editing = ix == editingRect

      opacity = if _editing then 0.5 else 0.3

      opts = {
        key: ix
        d...
        tags
        scaleFactor
        maxPosition: {width, height}
      }

      onClick = (event)=>
        # Make sure we don't activate the general
        # general click or drag handlers
        event.stopPropagation()
        if event.shiftKey
          do actions.addLink(ix)
        else
          do actions.selectAnnotation(ix)

      if _editing
        return h ActiveTag, {
          delete: actions.deleteAnnotation(ix)
          update: actions.updateAnnotation(ix)
          onSelect: @toggleSelect
          enterLinkMode: ->
          opts...
        }
      return h Tag, {onClick, opts...}

  render: ->
    {editingRect, width, height, image_tags,
     scaleFactor, tags, rest...} = @props
    size = {width, height}
    {selectIsOpen} = @state
    if not editingRect?
      selectIsOpen = false

    onClick = @disableEditing
    h 'div', [
      h TypeSelector, {
        tags,
        isOpen: selectIsOpen
        onClose: => @setState {selectIsOpen: false}
        onItemSelect: @selectTag
      }
      h 'div.overlay', {style: size, onClick}, @renderAnnotations()
      h AnnotationLinks, {image_tags, scaleFactor, tags, size...}
    ]

  selectTag: (tag)=>
    # Selects tag for active annotation
    {actions, editingRect} = @props
    fn = actions.updateAnnotation(editingRect)
    fn {tag_id: {$set: tag.tag_id}}
    @setState {selectIsOpen: false}

  handleDrag: =>
    {subject} = event
    {x,y} = subject
    {clickDistance, currentTag, scaleFactor, editingEnabled} = @props
    return if not editingEnabled
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
    @setState {inProgressAnnotation: rect}

  handleAddAnnotation: =>
    {shiftKey} = event.sourceEvent
    {actions, editingRect} = @props
    {inProgressAnnotation: r} = @state
    @setState {inProgressAnnotation: null}

    return unless r?
    if shiftKey and editingRect?
      # We are adding a box to the currently
      # selected annotation
      fn = actions.updateAnnotation(editingRect)
      fn {boxes: {$push: r.boxes}}
    else
      actions.appendAnnotation r

  disableEditing: =>
    {actions,editingRect} = @props
    if editingRect?
      __ = {editingRect: {$set: null}}
      actions.updateState __

  toggleSelect: =>
    return unless @props.editingRect?
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
    ]

  componentDidMount: ->
    el = select findDOMNode @

    # Set up dragging when rectangle is not clicked
    @edgeDrag = drag()
      .on "drag", @handleDrag
      .on "end", @handleAddAnnotation
      .clickDistance @props.clickDistance

    el.call @edgeDrag

Overlay = HotkeysTarget(Overlay)

export {Overlay}
