; increment by one
(define (++ x)
  (pp (cons '++ (cons x '())))
  (+ x 1))

; decrement by one
(define (-- x)
  (pp (cons '-- (cons x '())))
  (- x 1))

; a + b
(define (sum a b)
  (cond
    ((= a 0) 
        (pp b)
        b)
    (else 
        (pp (cons '++ 
                  (cons (cons 'sum 
                              (cons (cons '-- 
                                          (cons a '())) 
                                    (cons b '()))) 
                        '() )))
        (++ (sum (-- a) b)))))

(pp (sum 5 10))
