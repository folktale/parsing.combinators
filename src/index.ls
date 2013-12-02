# # parsing.combinators

/** ^
 * Copyright (c) 2013 Quildreen Motta
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation files
 * (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

# Packrat parser combinator implementation.

Maybe = require 'monads.maybe'
Either = require 'monads.either'


export class State
  (input, index) ->
    @input  = input
    @index  = index
    @length = input.length - index
    
  to-string: -> "State(#{@input.slice @index})"

  slice: (start, end) -> @input.slice start + @index, end + @index
  head: ->
    | @index < @length => Maybe.Just @input[index]
    | otherwise        => Maybe.Nothing!
  rest: -> @slice 1, @length

  consume: (size) ->
    | size > @length => Maybe.Nothing!
    | otherwise      => Maybe.Just (@slice 0, size)

  skip: (size) -> new State(@input, @index + size)

  position: -> new Position @input, @index



export class Position
  (input, index) ->
    @input = input
    @index = index

  to-lines: (start, end) ->
    @input.slice start, end
          .split /\r?\n/

  line: -> (@to-lines 0, @index).length
  column: -> (@to-lines 0, @index)[*-1].length

  context: (depth) ->
    lines = @to-lines 0, @input.length
    line  = @line!
    start = Math.max 0, (line - depth)
    end   = Math.min lines.length, line + depth

    lines.slice start, end

  to-string: ->
    line  = @line!
    col   = @column!
    lines = @context 3
    end   = Math.min line, 3

    """
    --- At line #line, column #col ---

    #{lines.slice 0, end .join '\n'}
    #{' ' * (col - 1)}^
    #{lines.slice end, @input.length .join '\n'}

    """
    

export fail = (reason, state, origin) ->
  message = "#reason\n#{state.position!}"
  a = Error.call this, message
  a.name   = "Parser Exception"
  a.reason = reason
  a.state  = state
  a.origin = origin

  a.show = ->
    | origin => "#{a.stack}\nArising from #{origin.show!}"
    | _      => "#{a.stack}"
  
  return a
    



# Parsing functions
export run = (parser, input) -->
  parser (new State input, 0)


parsed-or-fail = (error, value) -->
  value.get-or-else Either.Left error
  
matching = (state, a, b) -->
 | a is b => Either.Right [state.skip b.length; b]
 | _      => Either.Left [state; fail "Expected “#{a}”, found “#{b}”.", state]
  
export char = (a) -> (state) ->
  state.consume 1 
  .or-else -> 
    Either.Left [state; fail "Expected “#{a}”, but reached the end of the input.", state]
  .chain (matching state, a)




  
  
  
