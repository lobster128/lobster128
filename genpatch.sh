#!/bin/sh

# once everything is sucesful we can output a patch
cd gcc || exit
git pull trunk || exit
git add . || exit
git diff --cached >../gcc-patch.diff || exit
cd .. || exit
