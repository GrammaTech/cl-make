FROM python:3.8.5

# Install required system packages
RUN apt-get update && apt-get -y install sbcl

# Install quicklisp
RUN curl -O https://beta.quicklisp.org/quicklisp.lisp
RUN sbcl --load quicklisp.lisp \
  --eval '(quicklisp-quickstart:install)' \
  --eval '(let ((ql-util::*do-not-prompt* t)) (ql:add-to-init-file))'
ENV QUICK_LISP /root/quicklisp

# Install python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt
