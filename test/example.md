Observe:
```lisp
(format t "Hello, world 1!")
```
```
Hello, world 1!
NIL
```
Now, observe...

- ... again:

      (format t "Hello, world 2!")

  ```
  Hello, world 2!
  NIL
  ```

- And again:

  ```js
  console.log('Hello, world 3!');
  ```
  ```
  Hello, world 3!
  ```

- And yet again:

  ```lisp
  (format t "Hello, world 4!")
  ```

      Hello, world 4!
      NIL

But what's this?
```lisp
(format nil "Hello, world 5!")
```
Indeed.
```
"Hello, NOT world 5! ;)"
```
