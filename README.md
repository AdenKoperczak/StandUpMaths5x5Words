# The Problem
The goal of this program is to find all sets of five five-letter words where all
the letters are unique. This challenge was brought forth by a series of videos from
the wonderful Matt Parker which I highly recommend if you have not already seem
them. Here is the first video. <https://www.youtube.com/watch?v=_-AfhLQfb6w>. There
is also a podcast episode and further videos linked in the description.

## More Specifics
- How do I determine what a word is? In this case, `words_alpha.txt` contains
(what we are considering to be) every English word, lower case, one per line.
- What are valid letters? I am just using the standard, 26 letter alphabet. This
means that the set of words will end up having 25 of the 26 letters.

# My Implementation
To be clear, the main reason I took on this project was to help me learn a new
programming language, `zig`. Because I am just learning this language, I may not
have all the patterns down yet, so the code may be a bit messy. Furthermore,
there is not much code, I was making rapid iterations, and I was working on my
own, so I did not comment much. I made several versions which are explained in
[Versions]{#versions}. I also am only familiar with the basics of graph theory,
so my solution is not necessary optimal. Many others have made far better
solutions, but I tried to avoid pull from their code or ideas (manly by not
reading them). Finally, all of my solutions are single threaded, because I could
not be bothered. Maybe I will make a threaded version latter, who knows. Finally,
I did have an old C version, but it was a very basic iterative approach,
which was quite slow, so I have not included it.

# Building and Running the Code.
- `zig` 0.11.0 or greater
- made for Linux (distro probably does not matter).
- `make` for unoptimized
- `make fast` for optimized
- each version will be under `main_v*`
- each version takes the word list file as the first argument and the output
CSV file as the second argument.

First of all, you will need `zig` to build this. I used `zig` 0.11.0. `main_v4`
will not work without `zig` 0.11. All of the code can be build with a simple
`make` call, but this will make unoptimized versions. `make fast` will make a
optimized versions. I do not know how to use `zig`'s build environment, and it is
a bit broken on my computer anyway, so I used `make` instead.

The input file is one word per line, and the output file is a CSV with each line
containing one set of words.

# My Computer
I am running this code on `WSL` on a Windows 10 laptop. I have a AMD Ryzen 9
Mobile 4900HS with a base speed of 3 GHz. I was using the `time` command to
measure the times. All times are in `[m]m:ss` format.

# Versions {#versions}
## `main_v1`
About 2:30.

This version uses a simple iterative approach which further version build on.
It stores words as bit-masks for quicker comparisons. It does not recheck
already checked combinations of words. It also implements one algorithmic
optimization. It only checks words that will work with the first word in each
layer. This improves performance, but is pretty basic. It also uses unbuffered
IO, which is slow, but not too slow for this version.

## `main_v2`
About 3:00

This version is just `main_v1` but using pointers in place of indices. It is
slower than `main_v1` but I am unsure why. I was struggling to disassemble the
code in `gdb` and ended up moving on to `main_v3`.

## `main_v3`
About 0:16

The main improvement in this version is that I only use words that will work
for the previous words in the set when looking for the next word. That simple
change improved the speed to about 0:28 seconds. This improvement also removed
some extra allocations done during the reading of the file, which may have been
leading to inefficacies. At this point I realized that the system time reported
by `time` was around 12 seconds. Experimenting with it a bit I realized `zig`
does not use buffering on IO by default. So I added buffering and saved
essentially all of that time, bringing it to around 0:16.

## `main_v4`
About 0:16

This is essentially the same as `main_v3`, with a few low level changes. First
of all, I switched to using `mmap` for file IO. I do not think this actually
helps that much, but I did it any ways. (This is something I say others do, and
it helped them, but I think that had more to do with multithreading than anything
else, and the improvements were small in comparison to my total time.) I also
switched out a data structure that was separated into multiple variables and
used manually into a proper `sturct` (class). This just made the code somewhat
nicer.

# Future Optimizations
## Letter Based
This is roughly based off other solutions, but I only read a brief description,
and I do not know did not look at their code. This is what I have read.
[Spreadsheet with others submissions](https://www.youtube.com/redirect?event=video_description&redir_token=QUFFLUhqbmZFRWpoMkI4dGkyM2plejN5MFE2U296U2ZFUXxBQ3Jtc0trbTVCMmtNOHRXR2xhOTRKckEtUllYX2VXRy1oX19tSVJxMTFqYTZMRjVvYTN1OVN6MVZmd185N2Y0QmNReTZvdEZPeVlac2plQnY0WHg4VHpYY01yVFpzSHZUUjIzUk9RUk12ZlV5NlNnazdBVjhaZw&q=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2Fd%2F11sUBkPSEhbGx2K8ah6WbGV62P8ii5l5vVeMpkzk17PI%2Fedit%23gid%3D0&v=c33AZBnRHks)
The main optimization I would like to add is separating words into groups based
off what letter they do not have (one group with all words without 'a',
one group with all words without 'b', etc), and only checking those without the
first letter of the next potential word. If implemented well, I believe this
will improve my speed somewhat. This would only include the sections that
already work with previous words (like in `main_v3`).

## Multithreading
I might do this. It could help. It is also the most obvious way to improve the
speed, so I may or may not do it.

## Anything Else I Think Of
Maybe there is some optimization I think of and want to implement, I will
implement it.


