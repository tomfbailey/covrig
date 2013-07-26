from fabric.api import *

# Analytics modules
from Container import Container

class Memcached(Container):
    """ Memcached class """

    def __init__(self, _image, _user, _pwd):
        Container.__init__(self, _image, _user, _pwd)
  
    def compile(self):
        """ compile Memcached """
        with cd('/home/memcached'):
           with settings(warn_only=True):
               result = run(("sh autogen.sh && sh configure && make clean && "
                             "make CFLAGS+='-fprofile-arcs -ftest-coverage -g -O0 -pthread'"))
               if result.failed:
                   self.compileError = True

    def make_test(self):
        """ run the test suite """
        # if compile failed, skip this step
        if self.compileError == False: 
            with cd('/home/memcached'):
                with settings(warn_only=True):
                    result = run('make test')
                    if result.failed:
                        self.maketestError = result.return_code
