#!/bin/bash
echo "compiling cubicle again ..."
make clean
./configure
make 
