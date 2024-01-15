#!/bin/bash

for x in {10..24}; do
	echo "Day$x"
	./gpt.exs score day$x 50 4
	echo "Day$x"
	./gpt.exs score day$x 50 4
done

