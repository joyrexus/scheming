Monads
======

The following is Dave Herman's *Schemer's Introduction to Monads*


## Intro

This will be an introduction to monads from a Lisp/Scheme perspective,
with the assumption that the reader is comfortable with continuations,
CPS, accumulators, and accumulator-passing style.

The main insight of monads is that all side effects, from mutation to
I/O to non-termination, have one thing in common: order of evaluation
matters. In simple, terminating, pure lambda expressions, the order of
evaluation is completely irrelevant: no matter how you reduce it, the
final result is the same with no observable differences. But when you
have side effects, they have to happen in the right order. (Monads
aren't the only formalism for dealing with this -- CPS and A-normal
form do, too. But they're all related.)


## Continuation-Passing Style

So monads are about talking about effects in the context of a pure
semantics. Consider trying to implement the following impure program
in a pure subset of Scheme:

    (begin (turn-on-safety!)
           (pull-trigger!))

In our pure Scheme, we must define BEGIN to evaluate both its
arguments (we'll just stick to a two-argument definition) and evaluate
to the value of the second. With the naive definition:

    (define (begin v1 v2) v2)

a pure Scheme might evaluate the program in arbitrary order:

    #|
       (begin (turn-on-safety!)
              (pull-trigger!))
    -> (begin (turn-on-safety!)  ; effect: pull-trigger!
              #<void>)
    -> (begin #<void>            ; effect: turn-on-safety!
              #<void>)
    -> #<void>
    |#

That's no good. We've just accidentally shot one of our thesis
committee members. Whoops. Let's CPS our programs so we can enforce
the evaluation order (I'm using the infix [[--]] to represent the
CPS-translation of an expression):

    #|
      [[(begin (turn-on-safety!)
               (pull-trigger!))]]
    = (lambda (k)
        ([[turn-on-safety!]] (lambda (res1)
                               ([[pull-trigger!]] (lambda (res2)
                                                    (k res2))))))
    |#

So in a program written in CPS, we can define BEGIN as:

    (define (begin cps-exp1 cps-exp2)
      (lambda (k)
        (cps-exp1 (lambda (res1) 
                    (cps-exp2 (lambda (res2)
                                (k res2)))))))

Notice that the result of the first expression is received in the
argument res1, and subsequently ignored (no subexpression refers to
res1).


## Accumulator-Passing Style.

Now, we also know how to write programs in accumulator-passing style,
where all procedures have to take an extra argument that represents a
"register" that's being updated as a computation proceeds. Consider a
little random-number generator:

    (define seed (current-time))

    (define (rand)
      (let ([ans (modulo (* seed 16807) 2147483647)])
        (begin (set! seed ans)
               ans)))

At every application of RAND, it updates the seed to the newly
generated random number. If we were to implement this in pure Scheme,
we'd need to pass around the seed as an extra argument through any
procedures that might update its value. We'd also have all our
procedures return a pair of values: the actual result of the
procedure, plus the new seed, in case it got updated during the
computation of the procedure's result.

    ;; rand : number -> (number x number)
    (define (rand seed)
      (let ([ans (modulo (* seed 16807) 2147483647)])
        (cons ans ans)))

    ;; rand-point : number -> (point x number)
    (define (rand-point seed)
      (let* ([r1 (rand seed)]
             [r2 (rand (cdr r1))]
             [r3 (rand (cdr r2))])
        (cons (make-point (car r1) (car r2) (car r3))
              (cdr r3))))

    ;; rand-segment : number -> (segment x number)
    (define (rand-segment seed)
      (let* ([r1 (rand-point seed)]
             [r2 (rand-point (cdr r1))])
        (cons (make-segment (car r1) (car r2))
              (cdr r2))))

The whole program would start with an initial seed like so:

    (run-my-program (current-time))

Each one of these procedures has a couple features in common, namely
that they take a "seed" parameter and return a pair consisting of
their result and the new seed. Let's start abstracting that out by
currying the seed parameter:

    ;; rand : -> (number -> (number x number))
    (define (rand)
      (lambda (seed)
        (let ([ans (modulo (* seed 16807) 2147483647)])
          (cons ans ans))))

    ;; rand-point : -> (number -> (point x number))
    (define (rand-point)
      (lambda (seed)
        (let* ([r1 ((rand) seed)]
               [r2 ((rand) (cdr r1))]
               [r3 ((rand) (cdr r2))])
          (cons (make-point (car r1) (car r2))
                (cdr r2)))))

    ;; rand-segment : -> (number -> (segment x number))
    (define (rand-segment)
      (lambda (seed)
        (let* ([r1 ((rand-point) seed)]
               [r2 ((rand-point) (cdr r1))])
          (cons (make-segment (car r1) (car r2))
                (cdr r2)))))

Any procedure that can't see or change the value of the seed can be
left unchanged. We call the procedures that can have side effects
"operations," and procedures that can't "pure." For example, we could
write a distance function:

    (define (distance pt1 pt2)
      (sqrt (+ (sqr (- (point-x pt1) (point-x pt2)))
               (sqr (- (point-y pt1) (point-y pt2)))
               (sqr (- (point-z pt1) (point-z pt2))))))

This function doesn't affect the seed, so it stays pure. It doesn't
take an extra parameter to represent the current seed, and it doesn't
return a pair. This means that any possibly-effectful procedure can
call distance, but distance can't call any possibly-effectful
procedure (since it would disregard the effect and wouldn't pass it on
to the next operation).

We could simulate getting and setting the value of the seed as
operations:

    ;; get-seed : -> (number -> (number x number))
    (define (get-seed)
      (lambda (seed)
        (cons seed seed)))

    ;; set-seed : number -> (number -> (void x number))
    (define (set-seed new)
      (lambda (old)
        (cons (void) new)))

We can abstract the common pattern in the types, too: we say that an
operation that returns a value of type alpha has type T(alpha), where:

    T(alpha) = number -> (alpha x number)

So our operations have the following types:

    get-seed     : -> T(number)
    set-seed     : number -> T(void)
    rand         : -> T(number)
    rand-point   : -> T(point)
    rand-segment : -> T(segment)

Next we try to define BEGIN like before, only instead of in CPS, it's
just threading the accumulator through:

    ;; begin : T(alpha) T(beta) -> T(beta)
    (define (begin comp1 comp2)
      (lambda (seed0)
        (let* ([res1 (comp1 seed0)]
               [val1 (car res1)]
               [seed1 (cdr res1)])
          (comp2 seed1))))

Like the CPS version, this BEGIN is an "operator combinator:" it takes
two operations and returns a new operation. This isn't quite useful
for implementing our operations, though:

    (define (rand)
      (begin (get-seed)
             (let ([ans (modulo (* ??? 16807) 2147483647)])
               (begin (set-seed ans)
                      (lambda (seed)
                        (cons ans ans))))))

How does the second operation in RAND get the current seed from the
GET-SEED operation? The problem is that BEGIN disregards the result of
the first operation. Let's write a new combinator that makes the
result of the first operation available to the second:

    ;; pipe : T(alpha) (alpha -> T(beta)) -> T(beta)
    (define (pipe comp1 build-comp2)
      (lambda (seed0)
        (let* ([res1 (comp1 seed0)]
               [val1 (car res1)]
               [seed1 (cdr res1)])
          ((build-comp2 val1) seed1))))

This new combinator takes an operation and a function that receives
the result of the first operation and constructs a second operation
based on the result of the first. Finally, it runs the second
operation.

    (define (rand)
      (pipe (get-seed)
            (lambda (seed)
              (let ([ans (modulo (* seed 16807) 2147483647)])
                (begin (set-seed ans)
                       (lambda (seed)
                         (cons ans ans)))))))

We also abstract out an operation for "lifting" a pure value as an
operation:

    ;; lift : alpha -> T(alpha)
    (define (lift v)
      (lambda (seed)
        (cons v seed)))

Now we can clean up the end of RAND:

    (define (rand)
      (pipe (get-seed)
            (lambda (seed)
              (let ([ans (modulo (* seed 16807) 2147483647)])
                (begin (set-seed ans)
                       (lift ans))))))

Every monad has a type constructor T for talking about its
"operations" as well as two operations:

    lift : alpha -> T(alpha)
    pipe : T(alpha) (alpha -> T(beta)) -> T(beta)

[The operations go by other names: sometimes pipe is known as bind,
`>>=`, \*, or `let`. The lift operation is often called unit or return.]

Furthermore, its operations must satisfy the following three laws:

    (pipe (lift x) f)   = (f x)
    (pipe m lift)       = m
    (pipe (pipe m f) g) = (pipe m (lambda (x) (pipe (f x) g)))

[I'm tired and I don't feel like proving the monad laws hold for our
example. Actually, they probably don't because our version of pipe has
two arguments (instead of being completely curried) -- non-termination
would screw this up. Oh well.]

The monad can have any other operations as long as they don't
invalidate the laws.

Notice that an operation in our monad is actually a function that
needs an initial seed in order to produce a value. Also, notice that
the result of running an operation produces a pair of values
containing the final value plus the accumulated seed. Since we're
really just interested in the final value, we can construct a "run"
procedure to execute a monadic operation and extract its final value:

    ;; T(alpha) -> alpha
    (define (run m)
      (car (m (current-time))))

Notice also that this is the only way to "get out" of the monad, i.e.,
to go from T(alpha) to alpha. A monadic operation is built up with
combinators to produce one long chain of operations and then "run"
with a top-level procedure. This top-level procedure is very similar
to the process of running a CPS-ed program with an initial
continuation.


## Summary.

The two major concepts of monads as I've described them are:

    1. enforcing evaluation order
    2. abstracting away accumulators

The PIPE operation is a combinator for building a compound operation
from two smaller operations; it forces the operations to be performed
in order in much the same way as CPS. (In fact, it turns out that CPS
is a special case of a monad.)

This allows us to add effects to a pure core language so that the
effects will be guaranteed to happen in the right order. This is
useful for programming language semantics, because it lets us model
useful language features like mutable state and first-class
continuations in a pure functional semantics (i.e., lambda-calculus),
and it lets us reason abstractly about sequential execution of
effects.

It's also used in Haskell as a way to perform sequential operations in
a lazy language. In particular they use monads to perform I/O so that
all I/O operations are guaranteed to happen in the right order. They
also use monads to simulate various kinds of effects that they decided
to leave out of the base language (e.g., mutable state and first-class
continuations).


## More

I've stuck to a programmer's view of monads. I haven't described the
use of the algebraic laws, nor the math behind them. In fact, I
haven't even defined monads. The reason is that a monad is really a
semantic object, which is hard to point to when you're looking at raw
code. So I've decided to stick just to the intuitions and leave the
precise definitions for another day. So there's lots more to learn.
