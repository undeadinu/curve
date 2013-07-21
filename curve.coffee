window.Curve = window.Curve or {}

utils =
  getObjectFromNode: (domNode) ->
    $.data(domNode, 'curve.object')
  setObjectOnNode: (domNode, object) ->
    $.data(domNode, 'curve.object', object)

_.extend(window.Curve, utils)

attrs = {fill: '#ccc'}
utils = window.Curve

###
  TODO
  * draw handles
  * move handles
  * move nodes
  * move entire object
  * select/deselect things
  * make new objects
###

#
class Path
  constructor: () ->
    @path = null
    @nodes = []
    @isClosed = false
    @path = @_createRaphaelObject([])

  addNode: (node) ->
    @nodes.push(node)
    @render()

  close: ->
    @isClosed = true
    @render()

  render: (path=@path)->
    path.attr(path: @toPathArray())

  toPathArray: ->
    path = []
    lastPoint = null

    makeCurve = (fromNode, toNode) ->
      curve = ['C']
      curve = curve.concat(fromNode.getAbsoluteHandleOut().toArray())
      curve = curve.concat(toNode.getAbsoluteHandleIn().toArray())
      curve = curve.concat(toNode.point.toArray())
      curve

    for node in @nodes

      if path.length == 0
        path.push(['M'].concat(node.point.toArray()))
      else
        path.push(makeCurve(lastNode, node))

      lastNode = node

    if @isClosed
      path.push(makeCurve(@nodes[@nodes.length-1], @nodes[0]))
      path.push(['Z'])

    path

  _createRaphaelObject: (pathArray) ->
    path = raphael.path(pathArray).attr(attrs)
    utils.setObjectOnNode(path.node, this)
    path


#
class Point extends EventEmitter
  @create: (x, y) ->
    return x if x instanceof Point
    new Point(x, y)

  constructor: (x, y) ->
    @set(x, y)

  set: (@x, @y) ->
    [@x, @y] = @x if _.isArray(@x)
    @emit 'change'

  add: (other) ->
    new Point(@x + other.x, @y + other.y)

  toArray: ->
    [@x, @y]

#
class Curve
  constructor: (@point1, @handle1, @point2, @handle2) ->

#
class Node extends EventEmitter
  constructor: (point, handleIn, handleOut) ->
    @point = Point.create(point)
    @handleIn = Point.create(handleIn)
    @handleOut = Point.create(handleOut)
    @isBroken = false
    @_curveIn = null
    @_curveOut = null

  getAbsoluteHandleIn: ->
    @point.add(@handleIn)
  getAbsoluteHandleOut: ->
    @point.add(@handleOut)

#
class SelectionModel extends EventEmitter
  constructor: ->
    @selected = null
    @selectedNode = null

  setSelected: (selected) ->
    old = @selected
    @selected = selected
    @emit 'change:selected', object: @selected, old: old

  setSelectedNode: (selectedNode) ->
    old = @selectedNode
    @selectedNode = selectedNode
    @emit 'change:selectedNode', node: @selectedNode, old: old

  clearSelected: ->
    @setSelected(null)

  clearSelectedNode: ->
    @setSelectedNode(null)

#
class SelectionView
  nodeSize: 5

  constructor: (@model) ->
    @path = null
    @nodeEditors = []

    @model.on 'change:selected', @onChangeSelected
    @model.on 'change:selectedNode', @onChangeSelectedNode

  onChangeSelected: ({object}) =>
    @setSelectedObject(object)
  onChangeSelectedNode: ({node, old}) =>
    nodeEditor = @_findNodeEditorForNode(old)
    nodeEditor.setEnableHandles(false) if nodeEditor

    nodeEditor = @_findNodeEditorForNode(node)
    nodeEditor.setEnableHandles(true) if nodeEditor

  setSelectedObject: (object) ->
    @path.remove() if @path
    @path = null
    if object
      @path = object.path.clone().toFront()
      @path.node.setAttribute('class', 'selected-path')
      object.render(@path)

    @_createNodeEditors(object)

  _createNodeEditors: (object) ->
    if object
      nodeDiff = object.nodes.length - @nodeEditors.length
      @nodeEditors.push(new NodeEditor()) for i in [0...nodeDiff] if nodeDiff > 0

    for i in [0...@nodeEditors.length]
      @nodeEditors[i].setNode(object and object.nodes[i] or null)

  _findNodeEditorForNode: (node) ->
    for nodeEditor in @nodeEditors
      return nodeEditor if nodeEditor.node == node
    null

class NodeEditor
  nodeSize: 5
  handleSize: 3

  node = null
  nodeElement = null
  handleElements = null
  lineElement = null

  constructor: ->
    @_setupNodeElement()
    @_setupLineElement()
    @_setupHandleElements()
    @hide()

  hide: ->
    @visible = false
    @lineElement.hide()
    @nodeElement.hide()
    @handleElements.hide()

  show: ->
    @visible = true
    @lineElement.toFront()
    @nodeElement.toFront().show()
    @handleElements.toFront()

    if @enableHandles
      @lineElement.show()
      @handleElements.show()
    else
      @lineElement.hide()
      @handleElements.hide()

  setEnableHandles: (@enableHandles) ->
    @show() if @visible

  setNode: (@node) ->
    @setEnableHandles(false)
    @render()

  render: ->
    return @hide() unless @node

    handleIn = @node.getAbsoluteHandleIn()
    handleOut = @node.getAbsoluteHandleOut()
    point = @node.point

    linePath = [['M', handleIn.x, handleIn.y], ['L', point.x, point.y], ['L', handleOut.x, handleOut.y]]
    @lineElement.attr(path: linePath)

    @handleElements[0].attr(cx: handleIn.x, cy: handleIn.y)
    @handleElements[1].attr(cx: handleOut.x, cy: handleOut.y)

    @nodeElement.attr(cx: point.x, cy: point.y)

    @show()

  _setupNodeElement: ->
    @nodeElement = raphael.circle(0, 0, @nodeSize)
    @nodeElement.node.setAttribute('class', 'node-editor-node')

  _setupLineElement: ->
    @lineElement = raphael.path([])
    @lineElement.node.setAttribute('class', 'node-editor-lines')

  _setupHandleElements: ->
    @handleElements = raphael.set()
    @handleElements.push(
      raphael.circle(0, 0, @handleSize),
      raphael.circle(0, 0, @handleSize)
    )
    @handleElements[0].node.setAttribute('class', 'node-editor-handle')
    @handleElements[1].node.setAttribute('class', 'node-editor-handle')


_.extend(window.Curve, {Path, Curve, Point, Node, SelectionModel, SelectionView})

window.main = ->
  @raphael = r = Raphael("canvas")
  @path = new Path(r)
  @path.addNode(new Node([50, 50], [-10, 0], [10, 0]))
  @path.addNode(new Node([80, 60], [-10, -5], [10, 5]))
  @path.addNode(new Node([60, 80], [10, 0], [-10, 0]))
  @path.close()

  @selectionModel = new SelectionModel()
  @selectionView = new SelectionView(selectionModel)

  @selectionModel.setSelected(@path)
  @selectionModel.setSelectedNode(@path.nodes[2])
