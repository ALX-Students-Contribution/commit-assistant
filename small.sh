#!/bin/bash

file="test.txt"
line="#-1234+users@git.git.com"

if grep -qw "$line" "$file"; then
	sed -i "s/^$line$/git/" $file 2>&1
else
	echo "$line" >> "$file"
fi

