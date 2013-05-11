; print each item in a list
(define print
    (lambda (x)
    (cond
        ((pair? x)
        (pp (car x))
        (print (cdr x)) ))))

; test equality of two values and print items if unequal
(define eq
    (lambda (x y)
    (cond
        ((equal? x y) #t)
        (else 
            (print (cons 'not_equal: (cons x (cons y ())))) 
            #f))))
