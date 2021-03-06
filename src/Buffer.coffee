EventEmitter = require('events').EventEmitter
Promise = require('bluebird')

class Buffer extends EventEmitter
  @_defaultBufferSize: 10

  @defaultBufferSize: (size) ->
    return Buffer._defaultBufferSize if !size?
    Buffer._defaultBufferSize = size

  constructor: (options = {}) ->
    @content = options.content ? []
    @size = options.size ? Buffer._defaultBufferSize
    @_sealed = options.sealed ? false

  isEmpty: ->
    @content.length == 0

  isFull: ->
    @content.length >= @size

  getContent: ->
    @content

  write: (data) ->
    throw new Error('Cannot write sealed buffer') if @_sealed == true
    throw new Error('Buffer is full') if @isFull()
    @content.push data
    @emit 'write', data
    @emit 'full' if @isFull()
    @

  append: (data) ->
    @appendArray [ data ]
    @

  appendArray: (dataArray) ->
    newSize = @content.length + dataArray.length
    @size = newSize if newSize > @size
    @write data for data in dataArray
    @

  writeAsync: (data) ->
    if !@isFull()
      Promise.resolve @write data
    else
      new Promise (resolve, reject) =>
        @once 'release', =>
          resolve @writeAsync data

  writeArrayAsync: (dataArray) ->
    return Promise.resolve() if dataArray.length is 0
    result = Promise.pending()
    @_writeArrayItem dataArray, result, 0

    result.promise

  _writeArrayItem: (dataArray, pendingPromise, index) ->
    @writeAsync dataArray[index]
      .done =>
        return pendingPromise.resolve() if index >= dataArray.length - 1
        @_writeArrayItem dataArray, pendingPromise, index + 1

  read: ->
    throw new Error('Buffer is empty') if @isEmpty()
    result = @content.shift()
    @emit 'release', result
    if @isEmpty()
      @emit 'empty'
      @emit 'end' if @_sealed == true
    result

  readAsync: ->
    if !@isEmpty()
      Promise.resolve(@read())
    else
      new Promise (resolve, reject) =>
        @once 'write', => resolve @readAsync()

  seal: ->
    throw new Error('Buffer already sealed') if @_sealed == true
    @_sealed = true
    @emit 'sealed'
    @emit 'end' if @isEmpty()
    @

  isSealed: ->
    @_sealed == true

  isEnded: ->
    @isSealed() && @isEmpty()

module.exports = Buffer
