SVG = require '../vendor/svg'

Node = require '../src/node'
Path = require '../src/path'
SelectionModel = require '../src/selection-model'
ObjectEditor = require '../src/object-editor'

describe 'ObjectEditor', ->
  [canvas, svgDocument, model, editor, path] = []
  beforeEach ->
    canvas = document.createElement('canvas')
    jasmine.attachToDOM(canvas)
    svgDocument = SVG(canvas)

  beforeEach ->
    model = new SelectionModel()
    editor = new ObjectEditor(svgDocument, model)
    path = new Path(svgDocument)
    path.addNode(new Node([50, 50], [-10, 0], [10, 0]))
    path.close()

  it 'ignores selection model when not active', ->
    expect(editor.isActive()).toBe false
    expect(editor.getActiveObject()).toBe null
    model.setSelected(path)
    expect(editor.isActive()).toBe false
    expect(editor.getActiveObject()).toBe null

  describe "when the ObjectEditor is active", ->
    beforeEach ->
      editor.activate()
      expect(editor.isActive()).toBe true
      expect(editor.getActiveObject()).toBe null

    it 'activates the editor associated with the selected object', ->
      model.setSelected(path)
      expect(editor.isActive()).toBe true
      expect(editor.getActiveObject()).toBe path
      expect(canvas.querySelector('svg circle.node-editor-node')).toShow()

      model.clearSelected()
      expect(editor.isActive()).toBe true
      expect(editor.getActiveObject()).toBe null
      expect(canvas.querySelector('svg circle.node-editor-node')).toHide()

    it 'deactivates the editor associated with the selected object when the ObjectEditor is deactivated', ->
      model.setSelected(path)
      expect(editor.isActive()).toBe true
      expect(editor.getActiveObject()).toBe path
      expect(canvas.querySelector('svg circle.node-editor-node')).toShow()

      editor.deactivate()
      expect(editor.isActive()).toBe false
      expect(editor.getActiveObject()).toBe null
      expect(canvas.querySelector('svg circle.node-editor-node')).toHide()