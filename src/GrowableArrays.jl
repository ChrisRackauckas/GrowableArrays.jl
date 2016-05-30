__precompile__()

module GrowableArrays
  using EllipsesNotation
  import Base: setindex!, getindex
  immutable GrowableArray{T,A,N} <: AbstractArray{T,N}
      data::Vector{A}
  end
  #=
  function GrowableArray(elem::Number)
    data = Vector{typeof(elem)}(0)
    push!(data,elem)
    GrowableArray{typeof(elem),typeof(elem),1}(data)
  end
  =#

  function GrowableArray(elem)
    data = Vector{typeof(elem)}(0)
    push!(data,elem)
    if typeof(elem) <: AbstractArray
      GrowableArray{eltype(elem),typeof(elem),ndims(elem)+1}(data)
    else
      GrowableArray{typeof(elem),typeof(elem),1}(data)
    end
  end
  Base.sizehint!(G::GrowableArray,i::Int) = sizehint!(G.data,i)
  Base.size(G::GrowableArray) = (length(G.data), size(G.data[1])...)
  Base.getindex(G::GrowableArray, i::Int) = G.data[i] # expand a linear index out
  Base.getindex(G::GrowableArray, i::Int, I::Int...) = G.data[i][I...]
  function Base.setindex!(G::GrowableArray, elem,i::Int) ##TODO: Add type checking on elem
    G.data[ind2sub(size(G), i)...] = elem
  end
  function Base.setindex!(G::GrowableArray, elem,i::Int,I::Int...)
    G.data[i][I...] = elem
  end
  function Base.push!(G::GrowableArray,elem)
    push!(G.data,elem)
  end

  immutable StackedArray{T,N,A} <: AbstractArray{T,N}
      data::A
      dims::NTuple{N,Int}
  end
  StackedArray(vec::AbstractVector) = StackedArray(vec, (length(vec), size(vec[1])...)) # TODO: ensure all elements are the same size
  StackedArray{A<:AbstractVector, N}(vec::A, dims::NTuple{N}) = StackedArray{eltype(eltype(A)),N,A}(vec, dims)
  Base.size(S::StackedArray) = S.dims
  Base.getindex(S::StackedArray, i::Int) = S.data[ind2sub(size(S), i)...] # expand a linear index out
  Base.getindex(S::StackedArray, i::Int, I::Int...) = S.data[i][I...]

  export StackedArray, GrowableArray, setindex!, getindex, ..

end # module
