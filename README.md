# GrowableArrays.jl

[![Build Status](https://travis-ci.org/ChrisRackauckas/GrowableArrays.jl.svg?branch=master)](https://travis-ci.org/ChrisRackauckas/GrowableArrays.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/893ct6vhp0f82e9u?svg=true)](https://ci.appveyor.com/project/ChrisRackauckas/growablearrays-jl)

GrowableArrays was developed by Chris Rackauckas. This package implements the data
structures GrowableArray and StackedArray which are designed to grow efficiently
yet be easy to access and transform into more traditional arrays.

To install the package, simply do

```julia
Pkg.add("GrowableArrays")
using GrowableArrays
```

The use of GrowableArrays is best shown by an example problem. Say at every step
of a loop we wished to append a matrix `u` to a vector `uFull`. One case where
this shows up is in solving Partial Differential Equations. The naive way to
solve this problem is to concatenate `u` to an array `uFull`. Such a code would
look as follows:

```julia
function test1()
  u =    [1 2 3 4
          1 3 3 4
          1 5 6 3
          5 2 3 1]

  uFull = u
  for i = 1:10000
    uFull = hcat(uFull,u)
  end
  uFull
end

function test2()
  u =    [1 2 3 4
          1 3 3 4
          1 5 6 3
          5 2 3 1]

  uFull = u

  for i = 1:10000
    uFull = vcat(uFull,u)
  end
  uFull
end
```

For a more efficient implementation, we may want to store everything as a vector:

```julia
function test3()
  u =    [1 2 3 4
          1 3 3 4
          1 5 6 3
          5 2 3 1]

  uFull = Vector{Int}(0)
  sizehint!(uFull,10000*16)
  append!(uFull,vec(u))

  for i = 1:10000
    append!(uFull,vec(u))
  end
  reshape(uFull,4,4,10001)
  uFull
end
```

While this works, we have to mangle the code in our loop (adding vecs and reshaping
whenever we want to use it) in order to use this properly. However, if we instead do:

```julia
function test4()
  u =    [1 2 3 4
          1 3 3 4
          1 5 6 3
          5 2 3 1]

  uFull = Vector{Array{Int,2}}(0)
  push!(uFull,u)

  for i = 1:10000
    push!(uFull,u)
  end
  uFull
end
```

we can get timing results as follows:

```julia
#Compile Test Functions
test1()
test2()
test3()
test4()
numRuns = 10
t1 = @elapsed for i=1:numRuns test1() end
t2 = @elapsed for i=1:numRuns test2() end
t3 = @elapsed for i=1:numRuns test3() end
t4 = @elapsed for i=1:numRuns test4() end
println("Benchmark results: $t1 $t2 $t3 $t4")
#Benchmark results: 22.971889311 25.859405573 2.726375558 2.725142828
```

Notice that this implementation is an order of magnitude more efficient than the
naive choice, and is within error of the vector approach. What we
did here was create a vector of the matrix type and then repeatedly add
these matrices to the vector. It's easy to understand why this is much more efficient:
at each step of the loop this version only adds pointers to the new matrices,
whereas the naive version has to copy the matrix each time the `uFull` is grown.

The downside to this implementation is that it's hard to use as an actual result.
For example, to grab a time course of the first row of `u` (i.e. what the value
of `u` was at each step of the loop), we cannot do this without and reshaping
the data structure.

GrowableArray implements the solution of test 4 while re-defining the indexing
functions to make it more convenient to use. Since it implements the best solution
to the growing array problem, it has a constructor which is defined to be useful
in that situation. An example of its use is:

```julia
function test4()
  u =    [1 2 3 4
          1 3 3 4
          1 5 6 3
          5 2 3 1]

  uFull = GrowableArray(u)
  sizehint!(uFull,10000)
  for i = 1:10000
    push!(uFull,u)
  end
  uFull
end
```

Notice here we constrcted the GrowableArray by giving it the object `u`. This
creates a Vector which holds `typeof(u)`s and grows the array. `sizehint!` is
defined to sizehint the underlying array. With the wrapper, basic array usage
matches that of other arrays:

```julia
A = [1 2; 3 4]
B = [1 2; 4 3]
G = GrowableArray(A)
push!(G,A)
push!(G,A)
push!(G,A)
G[4,..] = B #Acts as a standard array
G[3] = B #Acts as a vector of matrices
K = G[3,..] + G[4,..]
```

Notice here we show the `..` notation. `..` simply fills in the other columns
with colons, meaning `G[3,..]==G[3,:,:]` (or `G[..,3]==G[:,:,3]`, and the number
of colons matches the number of remaining dimensions).  This is  useful since
what someone put in the GrowableArray could be an arbitrary sized array, so
this access will always work.

While because of the way our GrowableArray is stored (`Vector{Array}`) it is
the fastest implementation for growing the array, it is not as performant as
contiguous arrays for memory access. Thus after growing the array, one may wish
to change this to an array with dimensions `ndims(u)+1` (i.e. the new first dimension
is the one we concatenated along). To do this, we simply use:

```julia
Garr = copy(G)
```

The output `Garr` is a continguous array. GrowableArrays also exports the `..` notation
on AbstractArrays, and therefore we can still use the notation `Garr[..,1] = Garr[:,:,1]`.

## Note: Non-array elements

If someone tries to use a GrowableArray on a non-array element:

```julia
G2 = GrowableArray(1)
push!(G2,3)
```

then the GrowableArray will act like a regular vector of the objects which are
being added. Thus there is no reason to write special cases when the input is a
number rather than an array!

## Extra: The StackedArray

If we had already developed our code as in test 4 and have this `Vector{Array}`
which we wish to gain easier access to, the StackedArray is designed to take in
such a value and convert it to be as easy to use as the GrowableArray. An example
of the use is as follows:

```julia
u =    [1 2 3 4
        1 3 3 4
        1 5 6 3
        5 2 3 1]

uFull = Vector{Array{Int,2}}(0)
push!(uFull,u)

for i = 1:10000
  push!(uFull,u)
end
S = StackedArray(uFull)
Sarr = copy(S)
```

As before, Sarr is a now a standard multidimensional array.

## Acknowledgements

I would like to acknowledge StackExchange user Matt B. for coming up with the
StackedArray implementation and the idea for the GrowableArray. I would also like
to acknowledge M. Schauer for the `..` notation implementation.
