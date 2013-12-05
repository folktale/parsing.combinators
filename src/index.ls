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
  (input, index, additional) ->
    @input      = input
    @index      = index
    @length     = input.length - index
    @additional = additional
    
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

  modify: (f) -> new State @input, @index, (f @additional)
  put: (a) -> new State @input, @index, a
  get: -> @additional

  is-equal: (b) -> (b.input is @input) and (b.index is @index)



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
    

export class ParserException
  (reason, state) ->
    @reason = reason
    @state  = state
    @stack  = ''
    @origin = null

  make-stack: ->
    ^^this <<< { stack: (new Error).stack.split /\r?\n/ .slice 1 .join '\n' }

  aggregate: (b) ->
    ^^b <<< { origin: this }

  to-string: ->
    "ParserException: #{@get-reason!}\n#{@state.position!}\n\n#{@stack}\n#{@show-origin!}"

  get-reason: -> @reason
    
  show-origin: ->
    | origin => "Arising from #{@origin.to-string!}"
    | _      => ''

  

export class ExpectedException extends ParserException
  (expected, found, state) ->
    super '', state
    @expected = []
    @found    = found
    
  get-reason: -> switch @expected.length
    | 1 => "Expected #{repr @expected.0}, found #{repr @found}."
    | 2 => "Expected either #{@expected.map repr .join \or}, found #{repr @found}."
    | _ => "Expected one of #{expected.slice 0, -1 .map repr .join \,}, or #{repr @expected.0}, found #{repr @found}."
    
  aggregate: (b) ->
    | b.expected && b.found is @found => ^^b <<< expected: @expected ++ b.expected
    | otherwise                       => super b


repr = (a) -> switch typeof! a
  | \String => "“#{a}”"
  | \Array  => "[#{a.map repr .join ', '}]"
  | _       => a.to-string!
  


# Parsing functions
export run = (parser, input) -->
  parser (new State input, 0)


export expect = (state, a, b) -->
  | a is b => Either.Right [state.skip b.length; b]
  | _      => Either.Left [state; new ExpectedException a, b, state]
  
export fail = (reason, state) -->
  Either.Left [state, new ParserException reason, state]

export unexpect = (what, state) -->
  fail "Unexpected #{repr what}.", state
 
export result-or-error = (e, v) ->
  v.or-else ([state, _]) -> fail e, state

export char = (a) -> (state) ->
  state.consume 1 
  .or-else -> 
    Either.Left [state; fail "Expected “#{repr a}”, but reached the end of the input.", state]
  .chain (expect state, a)

export choice = (p1, p2) --> (state) ->
  p1 state
  .or-else ([_, e1]) -> do
                        p2 state
                        .or-else ([_, e2]) -> e2.aggregate e1
  
export sequence = (p1, p2) --> (s1) ->
  [s2, a] <- p1 s1 .chain
  [s3, b] <- p2 s2 .chain
  return Either.Right [s3, [a, b]]

export optional = (default_, p1) --> (state) ->
  p1 state .or-else -> new Either.Right [state, default_]

  
