Node = require "./node"

[COMMAND, NUMBER] = ['COMMAND', 'NUMBER']

parsePath = (pathString) ->
  #console.log 'parsing', pathString
  tokens = lexPath(pathString)
  parseTokens(groupCommands(tokens))

# Parses the result of lexPath
parseTokens = (groupedCommands) ->
  result = subpaths: []

  # Just a move command? We dont care.
  return result if groupedCommands.length == 1 and groupedCommands[0].type in ['M', 'm']

  # svg is stateful. Each command will set currentPoint.
  currentPoint = null
  currentSubpath = null
  addNewSubpath = (movePoint) ->
    node = new Node(movePoint)
    currentSubpath =
      closed: false
      nodes: [node]
    result.subpaths.push(currentSubpath)
    node

  slicePoint = (array, index) ->
    [array[index], array[index + 1]]

  # make relative points absolute based on currentPoint
  makeAbsolute = (array) ->
    if currentPoint?
      (val + currentPoint[i % 2] for val, i in array)
    else
      array

  # Create a node and add it to the list. When the last node is the same as the
  # first, and the path is closed, we do not create the node.
  createNode = (point, commandIndex) ->
    currentPoint = point

    node = null
    firstNode = currentSubpath.nodes[0]

    nextCommand = groupedCommands[commandIndex + 1]
    unless nextCommand and nextCommand.type in ['z', 'Z'] and firstNode and firstNode.point.equals(currentPoint)
      node = new Node(currentPoint)
      currentSubpath.nodes.push(node)

    node

  # When a command has more than one set of coords specified, we iterate over
  # each set of coords.
  #
  # Relative coordinates are relative to the last set of coordinates, not the
  # last command. (The SVG docs http://www.w3.org/TR/SVG/paths.html are not
  # super clear on this.)
  iterateOverParameterSets = (command, setSize, isRelative, callback) ->
    sets = command.parameters.length / setSize
    for setIndex in [0...sets]
      minindex = setIndex * setSize + 0
      maxIndex = setIndex * setSize + setSize
      paramSet = command.parameters.slice(minindex, maxIndex)
      paramSet = makeAbsolute(paramSet) if isRelative
      callback(paramSet, setIndex)
    return

  for i in [0...groupedCommands.length]
    command = groupedCommands[i]
    switch command.type
      when 'M', 'm'
        # Move to
        hasMoved = false
        setSize = 2
        isRelative = command.type == 'm'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          if hasMoved
            createNode(paramSet, i)
          else
            hasMoved = true
            currentPoint = paramSet
            addNewSubpath(currentPoint)

      when 'L', 'l'
        # Line to
        setSize = 2
        isRelative = command.type == 'l'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          createNode(slicePoint(paramSet, 0), i)

      when 'H', 'h'
        # Horizontal line
        setSize = 1
        isRelative = command.type == 'h'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          createNode([paramSet[0], currentPoint[1]], i)

      when 'V', 'v'
        # Vertical line
        setSize = 1
        isRelative = command.type == 'v'
        # command
        iterateOverParameterSets command, setSize, false, (paramSet) ->
          val = paramSet[0]
          val += currentPoint[1] if isRelative
          createNode([currentPoint[0], val], i)

      when 'C', 'c'
        # Bezier
        setSize = 6
        isRelative = command.type == 'c'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          currentPoint = slicePoint(paramSet, 4)
          handleIn = slicePoint(paramSet, 2)
          handleOut = slicePoint(paramSet, 0)

          lastNode = currentSubpath.nodes[currentSubpath.nodes.length - 1]
          lastNode.setAbsoluteHandleOut(handleOut)

          if node = createNode(currentPoint, i)
            node.setAbsoluteHandleIn(handleIn)
          else
            firstNode = currentSubpath.nodes[0]
            firstNode.setAbsoluteHandleIn(handleIn)

      when 'Q', 'q'
        # Bezier
        setSize = 4
        isRelative = command.type == 'q'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          currentPoint = slicePoint(paramSet, 2)
          handleIn = handleOut = slicePoint(paramSet, 0)

          lastNode = currentSubpath.nodes[currentSubpath.nodes.length - 1]
          lastNode.setAbsoluteHandleOut(handleOut)

          if node = createNode(currentPoint, i)
            node.setAbsoluteHandleIn(handleIn)
          else
            firstNode = currentSubpath.nodes[0]
            firstNode.setAbsoluteHandleIn(handleIn)

      when 'S', 's'
        # Shorthand cubic bezier.
        # Infer last node's handleOut to be a mirror of its handleIn.
        setSize = 4
        isRelative = command.type == 's'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          currentPoint = slicePoint(paramSet, 2)
          handleIn = slicePoint(paramSet, 0)

          lastNode = currentSubpath.nodes[currentSubpath.nodes.length - 1]
          lastNode.join('handleIn')

          if node = createNode(currentPoint, i)
            node.setAbsoluteHandleIn(handleIn)
          else
            firstNode = currentSubpath.nodes[0]
            firstNode.setAbsoluteHandleIn(handleIn)

      when 'T', 't'
        # Shorthand quadradic bezier.
        # Infer node's handles based on previous node's handles
        setSize = 2
        isRelative = command.type == 'q'
        iterateOverParameterSets command, setSize, isRelative, (paramSet) ->
          currentPoint = slicePoint(paramSet, 0)

          lastNode = currentSubpath.nodes[currentSubpath.nodes.length - 1]
          lastNode.join('handleIn')

          # Use the handle out from the previous node.
          # TODO: Should check if the last node was a Q command...
          # https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Paths#Bezier_Curves
          handleIn = lastNode.getAbsoluteHandleOut()

          if node = createNode(currentPoint, i)
            node.setAbsoluteHandleIn(handleIn)
          else
            firstNode = currentSubpath.nodes[0]
            firstNode.setAbsoluteHandleIn(handleIn)

      when 'Z', 'z'
        currentSubpath.closed = true

  for subpath in result.subpaths
    node.computeIsjoined() for node in subpath.nodes

  result

# Returns a list of svg commands with their parameters.
#   [
#     {type: 'M', parameters: [10, 30]},
#     {type: 'L', parameters: [340, 300]},
#   ]
groupCommands = (pathTokens) ->
  #console.log 'grouping tokens', pathTokens
  commands = []
  for i in [0...pathTokens.length]
    token = pathTokens[i]

    continue unless token.type == COMMAND

    command =
      type: token.string
      parameters: []


    while nextToken = pathTokens[i+1]
      if nextToken.type == NUMBER
        command.parameters.push(parseFloat(nextToken.string))
        i++
      else
        break

    #console.log command.type, command
    commands.push(command)

  commands

# Breaks pathString into tokens
lexPath = (pathString) ->
  numberMatch = '-0123456789.'
  separatorMatch = ' ,\n\t'

  tokens = []
  currentToken = null

  saveCurrentTokenWhenDifferentThan = (command) ->
    saveCurrentToken() if currentToken and currentToken.type != command

  saveCurrentToken = ->
    return unless currentToken
    currentToken.string = currentToken.string.join('') if currentToken.string.join
    tokens.push(currentToken)
    currentToken = null

  for ch in pathString
    if numberMatch.indexOf(ch) > -1
      saveCurrentTokenWhenDifferentThan(NUMBER)
      saveCurrentToken() if ch == '-'

      currentToken = {type: NUMBER, string: []} unless currentToken
      currentToken.string.push(ch)

    else if separatorMatch.indexOf(ch) > -1
      saveCurrentToken()

    else
      saveCurrentToken()
      tokens.push(type: COMMAND, string: ch)

  saveCurrentToken()
  tokens

module.exports = {lexPath, parsePath, groupCommands, parseTokens}
