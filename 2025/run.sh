#!/usr/bin/bash
d="day3"
if [[ $1 -eq 1 ]]; then
    # echo "1",$1,"1"
    ./$d < test_$d.txt
elif [[ $1 -eq 2 ]]; then
    # echo "0",$1,"0"
    ./$d < input_$d.txt
else
    zig build-exe $d.zig
fi
