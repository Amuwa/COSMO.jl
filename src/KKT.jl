module KKT
using OSSDPTypes, Helper
export factorKKT!

  function factorKKT!(p::OSSDPTypes.Problem,settings::OSSDPTypes.OSSDPSettings)
     if nnz(p.P) > 0 && p.P != p.P'
      # i,j,difference = findNonSymmetricComponent(p.P)
      # warn("Scaled P is not symmetric. [$(i),$(j)] differs by $(difference). Trying to correct.")
      p.P = p.P./2+(p.P./2)'
    end
    # KKT matrix M
    M = [p.P+settings.sigma*speye(p.n) p.A';p.A -spdiagm((1./p.ρVec))]
    # Do LDLT Factorization: A = LDL^T
    try
      p.F = ldltfact(M)
    catch
      warn("Problems performing the LDLT facorization. Matrix has one or more zero pivots. Reusing previous step matrix.")
    end
    return nothing
  end

end #MODULE