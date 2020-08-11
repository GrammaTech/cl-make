```lisp
(reduce (lambda (x y)
          (+ x y))
        '(1 2 3)
        :initial-value 5)
```
```
10
```
