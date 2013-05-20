(define (A x y)
  (cond ((= y 0) 0)
        ((= x 0) (* 2 y))
        ((= y 1) 2)
        (else (A (- x 1) 
                 (A x (- y 1))))))

(define (exponize x n)
  (cond ((= n 0) 1)
        (else (expt x (exponize x (- n 1))))))

(define (B x y)
  (cond ((= y 0) 0)
        ((= x 0) (* 2 y))
        ((= x 1) (expt 2 y))
        ((= x 2) (exponize 2 y))))

; (A 2 0)   ; 0             0
; (A 2 1)   ; 2             2^1     2
; (A 2 2)   ; 4             2^2     2^2
; (A 2 3)   ; 16            2^4     2^(2^2)
; (A 2 4)   ; 65536         2^16    2^(2^(2^2))

(define n 4) 

(pp (A 2 n))
(pp (B 2 n))
